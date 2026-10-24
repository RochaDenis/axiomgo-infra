data "aws_caller_identity" "atual" {}
data "aws_elb_service_account" "regiao" {}

resource "aws_security_group" "alb" {
  name        = "${var.nome}-alb"
  description = "Load balancer: entra HTTP/HTTPS da internet, sai so para o motor"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      description = "Internet"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] #trivy:ignore:AVD-AWS-0107 -- porta publica do produto, atras do WAF
    }
  }

  egress {
    description = "Motor nas sub-redes de app"
    from_port   = var.porta_motor
    to_port     = var.porta_motor
    protocol    = "tcp"
    cidr_blocks = var.cidrs_app
  }
}

# Registro de acesso do load balancer. O ALB só grava em bucket com SSE-S3.
#trivy:ignore:AVD-AWS-0132 -- o ALB so grava log em bucket com SSE-S3
resource "aws_s3_bucket" "acesso" {
  #checkov:skip=CKV_AWS_145:O ALB só grava log em bucket com SSE-S3, não aceita chave KMS própria.
  #checkov:skip=CKV_AWS_144:Residência de dados: o log fica na região.
  #checkov:skip=CKV_AWS_18:É o próprio bucket de log.
  #checkov:skip=CKV2_AWS_62:Notificações entram na fase de alarmes.
  #checkov:skip=CKV_AWS_21:Log de acesso não precisa de versões; expira em 90 dias.
  bucket        = "${var.nome}-alb-acesso-${data.aws_caller_identity.atual.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "acesso" {
  bucket                  = aws_s3_bucket.acesso.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#trivy:ignore:AVD-AWS-0132 -- o ALB so grava log em bucket com SSE-S3
resource "aws_s3_bucket_server_side_encryption_configuration" "acesso" {
  bucket = aws_s3_bucket.acesso.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "acesso" {
  bucket = aws_s3_bucket.acesso.id
  rule {
    id     = "expira-90-dias"
    status = "Enabled"
    filter {}
    expiration {
      days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "acesso" {
  bucket = aws_s3_bucket.acesso.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EntregaDoAlb"
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.regiao.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.acesso.arn}/AWSLogs/${data.aws_caller_identity.atual.account_id}/*"
      },
      {
        Sid       = "SoTls"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.acesso.arn, "${aws_s3_bucket.acesso.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.acesso]
}

resource "aws_lb" "this" {
  #checkov:skip=CKV2_AWS_76:O WAF associado (waf.tf) usa AWSManagedRulesKnownBadInputsRuleSet, que contém as regras de Log4j.
  name                       = var.nome
  load_balancer_type         = "application"
  internal                   = false #trivy:ignore:AVD-AWS-0053 -- porta publica do produto
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnets_publicas
  drop_invalid_header_fields = true
  enable_deletion_protection = true
  idle_timeout               = 300 # conversa por WebSocket fica aberta

  access_logs {
    bucket  = aws_s3_bucket.acesso.id
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.acesso]
}

resource "aws_lb_target_group" "motor" {
  #checkov:skip=CKV_AWS_378:O TLS termina no load balancer; dele ao motor é rede privada da VPC.
  name        = "${var.nome}-motor"
  port        = var.porta_motor
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # WebSocket: o mesmo cliente volta para a mesma tarefa.
  stickiness {
    type    = "lb_cookie"
    enabled = true
  }
}

# HTTP só redireciona. O ouvinte HTTPS entra quando o certificado for emitido.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP" #trivy:ignore:AVD-AWS-0054 -- so redireciona para HTTPS

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
