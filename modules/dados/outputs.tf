output "kms_dados_arn" {
  description = "Chave do dado do cliente (o servidor precisa dela para ler banco, senha e arquivos)."
  value       = aws_kms_key.dados.arn
}

output "banco_endpoint" {
  description = "Endereço de escrita do Aurora."
  value       = aws_rds_cluster.this.endpoint
}

output "banco_porta" {
  description = "Porta do Aurora."
  value       = aws_rds_cluster.this.port
}

output "banco_nome" {
  description = "Nome do banco."
  value       = aws_rds_cluster.this.database_name
}

output "banco_segredo_arn" {
  description = "Segredo (Secrets Manager) com usuário e senha do Aurora, gerido pela AWS."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}

output "cache_endpoint" {
  description = "Endereço do Valkey (TLS)."
  value       = aws_elasticache_serverless_cache.this.endpoint[0].address
}

output "cache_porta" {
  description = "Porta do Valkey."
  value       = aws_elasticache_serverless_cache.this.endpoint[0].port
}

output "bucket_arquivos" {
  description = "Bucket dos arquivos enviados."
  value       = aws_s3_bucket.arquivos.bucket
}
