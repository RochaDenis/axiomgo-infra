# Registro do tráfego da VPC (aceito e recusado), criptografado com chave própria.
data "aws_caller_identity" "atual" {}

resource "aws_kms_key" "logs" {
  description             = "${var.nome} - logs da rede"
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

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.nome}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/axiomgo/${var.nome}/vpc-flow-logs"
  retention_in_days = var.retencao_flow_logs_dias
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.nome}-flow-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.atual.account_id } }
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "grava-flow-logs"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = [aws_cloudwatch_log_group.flow_logs.arn, "${aws_cloudwatch_log_group.flow_logs.arn}:*"]
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs.arn
}
