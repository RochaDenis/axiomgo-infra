output "vpc_id" {
  description = "ID da VPC."
  value       = module.rede.vpc_id
}

output "subnets_publicas" {
  description = "Sub-redes públicas (load balancer)."
  value       = module.rede.subnets_publicas
}

output "subnets_app" {
  description = "Sub-redes dos servidores."
  value       = module.rede.subnets_app
}

output "subnets_dados" {
  description = "Sub-redes do banco e do cache."
  value       = module.rede.subnets_dados
}

output "cidrs_app" {
  description = "Faixas das sub-redes dos servidores."
  value       = module.rede.cidrs_app
}

output "vpc_cidr" {
  description = "Faixa da VPC."
  value       = module.rede.vpc_cidr
}
