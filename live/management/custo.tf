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

resource "aws_ce_anomaly_monitor" "servicos" {
  name              = "axiomgo-por-servico"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "diario" {
  name             = "axiomgo-anomalia-diaria"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.servicos.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomalia_minima_usd)]
    }
  }
}
