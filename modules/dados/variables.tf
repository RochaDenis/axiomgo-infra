variable "nome" {
  description = "Prefixo dos recursos (ex.: axiomgo-teste-br)."
  type        = string
}

variable "vpc_id" {
  description = "VPC da célula."
  type        = string
}

variable "subnets_dados" {
  description = "Sub-redes sem internet onde ficam banco e cache."
  type        = list(string)
}

variable "cidrs_app" {
  description = "Faixas dos servidores que podem falar com banco e cache."
  type        = list(string)
}

variable "acu_min" {
  description = "Capacidade mínima do Aurora. 0 = pausa sozinho sem conexão (teste); prod >= 0.5."
  type        = number
}

variable "acu_max" {
  description = "Capacidade máxima do Aurora (teto de custo)."
  type        = number
}

variable "leitor" {
  description = "Cria uma segunda instância (leitor/failover). Prod: true."
  type        = bool
  default     = false
}

variable "retencao_backup_dias" {
  description = "Dias de backup automático do Aurora."
  type        = number
  default     = 7
}

variable "cache_gb_max" {
  description = "Teto de memória do cache (GB). Limita o custo do ElastiCache Serverless."
  type        = number
  default     = 1
}
