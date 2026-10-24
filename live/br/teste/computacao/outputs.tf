output "ecr_url" {
  description = "Endereço do registro de imagens do motor."
  value       = module.computacao.ecr_url
}

output "cluster_nome" {
  description = "Cluster ECS."
  value       = module.computacao.cluster_nome
}

output "log_group" {
  description = "Grupo de logs do motor."
  value       = module.computacao.log_group
}

output "segredo_motor_arn" {
  description = "Segredo com as chaves de terceiros do motor."
  value       = module.computacao.segredo_motor_arn
}

output "papel_execucao_arn" {
  description = "Papel de execução das tarefas."
  value       = module.computacao.papel_execucao_arn
}

output "papel_tarefa_arn" {
  description = "Papel da tarefa."
  value       = module.computacao.papel_tarefa_arn
}
