# Base do servidor do motor: registro de imagens, cluster, logs, papéis e o cofre
# de segredos. O serviço (tarefas rodando) entra junto com a porta de entrada
# (load balancer), quando houver imagem e endereço. O grupo de segurança do
# servidor também nasce lá, junto do serviço que o usa.
data "aws_caller_identity" "atual" {}
data "aws_region" "atual" {}

resource "aws_kms_key" "app" {
  #checkov:skip=CKV_AWS_109:Política de chave KMS; "*" é a própria chave, administrada pela conta.
  #checkov:skip=CKV_AWS_111:Política de chave KMS; "*" é a própria chave.
  #checkov:skip=CKV_AWS_356:Política de chave KMS; "*" é a própria chave.
  description             = "${var.nome} - logs e imagens do motor"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Conta"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.atual.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchLogs"
        Effect    = "Allow"
        Principal = { Service = "logs.${data.aws_region.atual.region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnLike = { "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${data.aws_region.atual.region}:${data.aws_caller_identity.atual.account_id}:log-group:*" }
        }
      },
    ]
  })
}

resource "aws_kms_alias" "app" {
  name          = "alias/${var.nome}-app"
  target_key_id = aws_kms_key.app.key_id
}

# Imagens do motor. Tag imutável: o que roda é exatamente o commit testado.
resource "aws_ecr_repository" "motor" {
  name                 = "axiomgo-engine"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.app.arn
  }
}

resource "aws_ecr_lifecycle_policy" "motor" {
  repository = aws_ecr_repository.motor.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Guarda as 30 imagens mais novas"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 30 }
      action       = { type = "expire" }
    }]
  })
}

resource "aws_ecs_cluster" "this" {
  name = var.nome

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Teste usa Fargate Spot (até ~70% mais barato); prod usa Fargate comum.
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}

resource "aws_cloudwatch_log_group" "motor" {
  name              = "/axiomgo/${var.nome}/motor"
  retention_in_days = var.retencao_logs_dias
  kms_key_id        = aws_kms_key.app.arn
}

# Segredos do motor que não são da AWS (Clerk, OpenRouter, MCP, criptografia...).
# Nasce vazio: o valor entra uma vez, fora do Terraform, e nunca passa pelo estado.
resource "aws_secretsmanager_secret" "motor" {
  #checkov:skip=CKV2_AWS_57:Chaves de terceiros (Clerk, OpenRouter) giram no fornecedor, não pela AWS.
  name       = "${var.nome}/motor"
  kms_key_id = var.kms_dados_arn
}
