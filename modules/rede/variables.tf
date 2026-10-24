variable "nome" {
  description = "Prefixo dos recursos (ex.: axiomgo-teste-br)."
  type        = string
}

variable "cidr" {
  description = "Faixa da VPC. Uma /16 por ambiente, sem sobreposição entre células."
  type        = string
}

variable "zonas" {
  description = "Duas zonas de disponibilidade da região."
  type        = list(string)

  validation {
    condition     = length(var.zonas) == 2
    error_message = "Use exatamente duas zonas."
  }
}

variable "saida" {
  description = "Saída para a internet das sub-redes de aplicação: nat_gateway (prod) ou nat_instancia (teste, ~10x mais barata)."
  type        = string

  validation {
    condition     = contains(["nat_gateway", "nat_instancia"], var.saida)
    error_message = "saida deve ser nat_gateway ou nat_instancia."
  }
}

variable "retencao_flow_logs_dias" {
  description = "Retenção do registro de tráfego da VPC."
  type        = number
  default     = 365
}
