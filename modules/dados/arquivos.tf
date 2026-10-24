# Arquivos enviados pelos clientes desta célula. Ficam só nesta região.
resource "aws_s3_bucket" "arquivos" {
  #checkov:skip=CKV_AWS_144:Residência de dados: o arquivo do cliente não sai da região.
  #checkov:skip=CKV_AWS_18:Acesso registrado pelo CloudTrail da organização; log de acesso S3 entra na fase de alarmes.
  #checkov:skip=CKV2_AWS_62:Notificações entram na fase de alarmes.
  bucket = "${var.nome}-arquivos-${data.aws_caller_identity.atual.account_id}"

  tags = { Dado = "cliente" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "arquivos" {
  bucket = aws_s3_bucket.arquivos.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "arquivos" {
  bucket                  = aws_s3_bucket.arquivos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "arquivos" {
  bucket = aws_s3_bucket.arquivos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "arquivos" {
  bucket = aws_s3_bucket.arquivos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.dados.arn
    }
    bucket_key_enabled = true
  }
}

# Versão apagada ou substituída some depois de 30 dias; upload pela metade, em 7.
resource "aws_s3_bucket_lifecycle_configuration" "arquivos" {
  bucket = aws_s3_bucket.arquivos.id

  rule {
    id     = "versoes-antigas"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Só HTTPS.
resource "aws_s3_bucket_policy" "arquivos" {
  bucket = aws_s3_bucket.arquivos.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "SoTls"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.arquivos.arn, "${aws_s3_bucket.arquivos.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.arquivos]
}
