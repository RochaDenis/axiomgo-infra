output "validacao_certificado" {
  description = "Registro DNS (CNAME) que valida o certificado. Criar uma vez no DNS de axiomgo.io."
  value = [for o in aws_acm_certificate.this.domain_validation_options : {
    nome  = o.resource_record_name
    tipo  = o.resource_record_type
    valor = o.resource_record_value
  }]
}

output "endereco_alb" {
  description = "Para onde o CNAME do endereço público aponta."
  value       = aws_lb.this.dns_name
}

output "certificado_arn" {
  description = "Certificado do endereço público."
  value       = aws_acm_certificate.this.arn
}

output "alb_arn" {
  description = "Load balancer."
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "Grupo de destino do motor."
  value       = aws_lb_target_group.motor.arn
}

output "sg_alb_id" {
  description = "Grupo de segurança do load balancer (o motor só aceita tráfego dele)."
  value       = aws_security_group.alb.id
}
