locals {
  avisos_orcamento = {
    real_50      = { tipo = "ACTUAL", limite = 50 }
    real_80      = { tipo = "ACTUAL", limite = 80 }
    real_100     = { tipo = "ACTUAL", limite = 100 }
    previsto_100 = { tipo = "FORECASTED", limite = 100 }
  }
}

resource "aws_budgets_budget" "mensal" {
  name         = "axiomgo-mensal"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_mensal_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = local.avisos_orcamento

    content {
      comparison_operator        = "GREATER_THAN"
      notification_type          = notification.value.tipo
      threshold                  = notification.value.limite
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}

# Anomalia de custo: precisa do Cost Explorer ativado na conta (1 clique no console,
# até 24 h para liberar). Com ele ativo, a AWS cria sozinha o monitor por serviço e o
# alerta diário. O monitor por conta entra na 0b, junto com as contas-membro.
