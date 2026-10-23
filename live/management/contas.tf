# Contas-membro: uma por função, para isolar dano e custo (padrão AWS SRA).
# Cada conta precisa de um e-mail único; usamos endereços "+" da mesma caixa.
# Com a raiz centralizada (organizacao.tf), estas contas nascem sem senha de raiz.
locals {
  contas = {
    seguranca = { ou = aws_organizations_organizational_unit.seguranca.id, descricao = "GuardDuty Security Hub Config - admin delegado" }
    logs      = { ou = aws_organizations_organizational_unit.seguranca.id, descricao = "CloudTrail da organização e logs imutáveis" }
    teste-br  = { ou = aws_organizations_organizational_unit.workloads.id, descricao = "Teste da célula Brasil sa-east-1" }
    prod-br   = { ou = aws_organizations_organizational_unit.workloads.id, descricao = "Produção da célula Brasil sa-east-1" }
  }
}

resource "aws_organizations_account" "conta" {
  for_each = local.contas

  name      = "axiomgo-${each.key}"
  email     = replace(var.alert_email, "@", "+aws-${each.key}@")
  parent_id = each.value.ou

  # Mudar estes dois depois RECRIA a conta: ficam fixos.
  iam_user_access_to_billing = "ALLOW"
  role_name                  = "OrganizationAccountAccessRole"

  # Apagar do código só tira a conta da organização; nunca fecha a conta.
  close_on_deletion = false

  # Etiqueta de conta só aceita letras, números, espaço e _ . : / = + - @
  tags = {
    Funcao = each.value.descricao
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name]
  }
}
