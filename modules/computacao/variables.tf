variable "nome" {
  description = "Prefixo dos recursos (ex.: axiomgo-teste-br)."
  type        = string
}

variable "kms_dados_arn" {
  description = "Chave do dado do cliente (banco, senha, arquivos)."
  type        = string
}

variable "banco_segredo_arn" {
  description = "Segredo do Aurora (usuário e senha), gerido pela AWS."
  type        = string
}

variable "bucket_arquivos" {
  description = "Bucket dos arquivos enviados."
  type        = string
}

variable "retencao_logs_dias" {
  description = "Retenção dos logs do servidor."
  type        = number
  default     = 365
}
