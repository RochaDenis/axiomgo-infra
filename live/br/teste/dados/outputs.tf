output "kms_dados_arn" {
  description = "Chave do dado do cliente."
  value       = module.dados.kms_dados_arn
}

output "banco_endpoint" {
  description = "Endereço de escrita do Aurora."
  value       = module.dados.banco_endpoint
}

output "banco_porta" {
  description = "Porta do Aurora."
  value       = module.dados.banco_porta
}

output "banco_nome" {
  description = "Nome do banco."
  value       = module.dados.banco_nome
}

output "banco_segredo_arn" {
  description = "Segredo com usuário e senha do Aurora."
  value       = module.dados.banco_segredo_arn
}

output "cache_endpoint" {
  description = "Endereço do Valkey."
  value       = module.dados.cache_endpoint
}

output "cache_porta" {
  description = "Porta do Valkey."
  value       = module.dados.cache_porta
}

output "bucket_arquivos" {
  description = "Bucket dos arquivos enviados."
  value       = module.dados.bucket_arquivos
}
