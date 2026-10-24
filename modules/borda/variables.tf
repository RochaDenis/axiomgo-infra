variable "nome" {
  description = "Prefixo dos recursos (ex.: axiomgo-teste-br)."
  type        = string
}

variable "dominio" {
  description = "Endereço público do motor (ex.: api-br-develop.axiomgo.io)."
  type        = string
}

variable "vpc_id" {
  description = "VPC da célula."
  type        = string
}

variable "subnets_publicas" {
  description = "Sub-redes públicas onde fica o load balancer."
  type        = list(string)
}

variable "cidrs_app" {
  description = "Faixas dos servidores (destino do load balancer)."
  type        = list(string)
}

variable "porta_motor" {
  description = "Porta HTTP do motor."
  type        = number
  default     = 4000
}

variable "limite_por_ip_5min" {
  description = "Requisições por IP a cada 5 minutos antes de o WAF bloquear."
  type        = number
  default     = 2000
}
