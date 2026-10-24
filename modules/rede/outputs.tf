output "vpc_id" {
  description = "ID da VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Faixa da VPC."
  value       = aws_vpc.this.cidr_block
}

output "subnets_publicas" {
  description = "Sub-redes públicas (load balancer)."
  value       = [for z in var.zonas : aws_subnet.publica[z].id]
}

output "subnets_app" {
  description = "Sub-redes dos servidores."
  value       = [for z in var.zonas : aws_subnet.app[z].id]
}

output "subnets_dados" {
  description = "Sub-redes do banco e do cache (sem internet)."
  value       = [for z in var.zonas : aws_subnet.dados[z].id]
}

output "cidrs_app" {
  description = "Faixas das sub-redes dos servidores (para liberar acesso ao banco)."
  value       = [for z in var.zonas : local.app[z]]
}
