variable "alert_email" {
  description = "E-mail que recebe alertas de custo e de segurança."
  type        = string
  default     = "denis.rocha@axiomgo.io"
}

variable "budget_mensal_usd" {
  description = "Teto de gasto mensal da organização, em USD (decisão do Denis, 23/10/2026)."
  type        = number
  default     = 200

  validation {
    condition     = var.budget_mensal_usd > 0
    error_message = "O teto precisa ser maior que zero."
  }
}

variable "regioes_permitidas" {
  description = "Únicas regiões onde as contas-membro podem criar recursos (dado no país)."
  type        = list(string)
  default     = ["sa-east-1", "us-east-1", "eu-central-1"]
}
