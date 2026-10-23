# Trilha de auditoria da organização: todas as contas, todas as regiões, gravada na
# conta "logs" (criptografada, com validação de integridade e travada contra apagamento).
locals {
  conta_gerenciamento = data.aws_caller_identity.atual.account_id
  conta_logs          = aws_organizations_account.conta["logs"].id
  trilha_nome         = "axiomgo-organizacao"
  trilha_arn          = "arn:aws:cloudtrail:sa-east-1:${local.conta_gerenciamento}:trail/${local.trilha_nome}"
  bucket_trilha       = "axiomgo-cloudtrail-${local.conta_logs}"
}

data "aws_iam_policy_document" "chave_trilha" {
  #checkov:skip=CKV_AWS_111:Política de chave KMS; "*" é a própria chave.
  #checkov:skip=CKV_AWS_356:Política de chave KMS; "*" é a própria chave.
  #checkov:skip=CKV_AWS_109:Política de chave KMS; "*" é a própria chave, administrada pela conta logs.
  statement {
    sid       = "AdminDaContaLogs"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.conta_logs}:root"]
    }
  }

  statement {
    sid       = "CloudTrailCriptografa"
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trilha_arn]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${local.conta_gerenciamento}:trail/*"]
    }
  }

  statement {
    sid       = "CloudTrailDescreve"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "trilha" {
  provider = aws.logs

  description             = "Criptografia da trilha de auditoria da organizacao"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.chave_trilha.json
}

resource "aws_kms_alias" "trilha" {
  provider = aws.logs

  name          = "alias/axiomgo-cloudtrail"
  target_key_id = aws_kms_key.trilha.key_id
}

resource "aws_s3_bucket" "trilha" {
  #checkov:skip=CKV_AWS_144:Residência de dados: os logs ficam só em sa-east-1.
  #checkov:skip=CKV_AWS_18:Bucket de log; o acesso a ele já fica na própria trilha (sem log do log).
  #checkov:skip=CKV2_AWS_62:Notificações entram na fase de alarmes.
  provider = aws.logs

  bucket              = local.bucket_trilha
  object_lock_enabled = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "trilha" {
  provider = aws.logs

  bucket = aws_s3_bucket.trilha.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Retenção GOVERNANCE de 1 ano: ninguém apaga log antes do prazo sem a permissão especial
# de bypass (negada pela SCP a quem não é papel de plataforma).
resource "aws_s3_bucket_object_lock_configuration" "trilha" {
  provider = aws.logs

  bucket = aws_s3_bucket.trilha.id
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 365
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trilha" {
  provider = aws.logs

  bucket = aws_s3_bucket.trilha.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.trilha.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "trilha" {
  provider = aws.logs

  bucket                  = aws_s3_bucket.trilha.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "trilha" {
  provider = aws.logs

  bucket = aws_s3_bucket.trilha.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trilha" {
  provider = aws.logs

  bucket = aws_s3_bucket.trilha.id
  rule {
    id     = "arquivar-e-expirar"
    status = "Enabled"
    filter {}
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    expiration {
      days = 400
    }
    noncurrent_version_expiration {
      noncurrent_days = 400
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "bucket_trilha" {
  statement {
    sid     = "SomenteTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.trilha.arn,
      "${aws_s3_bucket.trilha.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "CloudTrailLeAcl"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trilha.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trilha_arn]
    }
  }

  statement {
    sid     = "CloudTrailGrava"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.trilha.arn}/AWSLogs/${local.conta_gerenciamento}/*",
      "${aws_s3_bucket.trilha.arn}/AWSLogs/${aws_organizations_organization.this.id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trilha_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "trilha" {
  provider = aws.logs

  bucket = aws_s3_bucket.trilha.id
  policy = data.aws_iam_policy_document.bucket_trilha.json

  depends_on = [aws_s3_bucket_public_access_block.trilha]
}

resource "aws_cloudtrail" "organizacao" {
  #checkov:skip=CKV_AWS_252:Alertas vêm do GuardDuty e Security Hub; SNS entra na fase de alarmes.
  #checkov:skip=CKV2_AWS_10:Envio ao CloudWatch Logs entra na fase de alarmes (custo por GB).
  name                          = local.trilha_nome
  s3_bucket_name                = aws_s3_bucket.trilha.id
  kms_key_id                    = aws_kms_key.trilha.arn
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [
    aws_s3_bucket_policy.trilha,
    aws_organizations_organization.this,
  ]
}
