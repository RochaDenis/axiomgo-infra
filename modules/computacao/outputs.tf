output "ecr_url" {
  description = "Endereço do registro de imagens do motor."
  value       = aws_ecr_repository.motor.repository_url
}

output "cluster_nome" {
  description = "Cluster ECS."
  value       = aws_ecs_cluster.this.name
}

output "log_group" {
  description = "Grupo de logs do motor."
  value       = aws_cloudwatch_log_group.motor.name
}

output "segredo_motor_arn" {
  description = "Segredo com as chaves de terceiros do motor."
  value       = aws_secretsmanager_secret.motor.arn
}

output "papel_execucao_arn" {
  description = "Papel de execução das tarefas."
  value       = aws_iam_role.execucao.arn
}

output "papel_tarefa_arn" {
  description = "Papel da tarefa (o que o código pode fazer)."
  value       = aws_iam_role.tarefa.arn
}
