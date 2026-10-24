output "validacao_certificado" {
  description = "Registro DNS que valida o certificado."
  value       = module.borda.validacao_certificado
}

output "endereco_alb" {
  description = "Para onde o CNAME de api-br-develop aponta."
  value       = module.borda.endereco_alb
}

output "certificado_arn" {
  description = "Certificado do endereço público."
  value       = module.borda.certificado_arn
}

output "alb_arn" {
  description = "Load balancer."
  value       = module.borda.alb_arn
}

output "target_group_arn" {
  description = "Grupo de destino do motor."
  value       = module.borda.target_group_arn
}

output "sg_alb_id" {
  description = "Grupo de segurança do load balancer."
  value       = module.borda.sg_alb_id
}
