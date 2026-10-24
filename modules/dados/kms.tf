# Uma chave para o dado do cliente desta célula: banco, cache, arquivos e senhas.
data "aws_caller_identity" "atual" {}
data "aws_region" "atual" {}

resource "aws_kms_key" "dados" {
  #checkov:skip=CKV_AWS_109:Política de chave KMS; "*" é a própria chave, administrada pela conta.
  #checkov:skip=CKV_AWS_111:Política de chave KMS; "*" é a própria chave.
  #checkov:skip=CKV_AWS_356:Política de chave KMS; "*" é a própria chave.
  description             = "${var.nome} - dado do cliente (banco, cache, arquivos)"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "Conta"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.atual.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = { Dado = "cliente" }
}

resource "aws_kms_alias" "dados" {
  name          = "alias/${var.nome}-dados"
  target_key_id = aws_kms_key.dados.key_id
}
