# WAF na frente do load balancer: regras gerenciadas da AWS + limite por IP.
locals {
  rotas_de_upload = [
    { caminho = "/api/v1/files", como = "STARTS_WITH" },
    { caminho = "/api/v1/import/", como = "STARTS_WITH" },
    { caminho = "/api/v1/materials/import", como = "EXACTLY" },
    { caminho = "/api/v1/technicians/import", como = "EXACTLY" },
  ]
}

resource "aws_wafv2_web_acl" "this" {
  name  = var.nome
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "regras-comuns"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
        # A regra de tamanho só conta aqui; quem bloqueia é "corpo-grande-fora-do-upload",
        # que libera corpo grande apenas nas rotas de envio de arquivo.
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            count {}
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "regras-comuns"
      sampled_requests_enabled   = true
    }
  }

  # Corpo acima de 8 KB só passa nas rotas de envio de arquivo (multipart do motor):
  # /api/v1/files, /api/v1/import/*, /api/v1/materials/import, /api/v1/technicians/import.
  rule {
    name     = "corpo-grande-fora-do-upload"
    priority = 15
    action {
      block {}
    }
    statement {
      and_statement {
        statement {
          label_match_statement {
            scope = "LABEL"
            key   = "awswaf:managed:aws:core-rule-set:SizeRestrictions_Body"
          }
        }
        statement {
          not_statement {
            statement {
              or_statement {
                dynamic "statement" {
                  for_each = local.rotas_de_upload
                  content {
                    byte_match_statement {
                      search_string         = statement.value.caminho
                      positional_constraint = statement.value.como
                      field_to_match {
                        uri_path {}
                      }
                      text_transformation {
                        priority = 0
                        type     = "NONE"
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "corpo-grande-fora-do-upload"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "entradas-maliciosas"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "entradas-maliciosas"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "ip-com-ma-reputacao"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "ip-com-ma-reputacao"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "limite-por-ip"
    priority = 40
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = var.limite_por_ip_5min
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "limite-por-ip"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.nome
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# Registro do WAF: só o que foi bloqueado, por 1 ano, criptografado, sem credencial.
data "aws_region" "atual" {}

resource "aws_kms_key" "waf" {
  #checkov:skip=CKV_AWS_109:Política de chave KMS; "*" é a própria chave, administrada pela conta.
  #checkov:skip=CKV_AWS_111:Política de chave KMS; "*" é a própria chave.
  #checkov:skip=CKV_AWS_356:Política de chave KMS; "*" é a própria chave.
  description             = "${var.nome} - log do WAF"
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

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.nome}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.waf.arn
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  # Credenciais nunca vão para o log.
  dynamic "redacted_fields" {
    for_each = ["authorization", "cookie", "x-api-key"]
    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  logging_filter {
    default_behavior = "DROP"
    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"
      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }
}
