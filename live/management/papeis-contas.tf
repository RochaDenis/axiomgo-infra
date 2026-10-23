# Papéis do Terraform nas contas-membro, criados pela organização (StackSet).
# O plan entra só com "leitura"; o apply, só com "escrita". O papel de administrador
# padrão (OrganizationAccountAccessRole) fica fora da esteira.
#
# A ativação do acesso confiável do StackSet é feita pela esteira com
# `aws cloudformation activate-organizations-access` (forma recomendada pela AWS).
resource "aws_cloudformation_stack_set" "papeis_terraform" {
  name             = "axiomgo-papeis-terraform"
  description      = "Papeis axiomgo-terraform-leitura e axiomgo-terraform-escrita nas contas-membro"
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = file("${path.module}/templates/papeis-terraform.yaml")

  parameters = {
    ContaGerenciamento = data.aws_caller_identity.atual.account_id
  }

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "papeis_terraform" {
  stack_set_name            = aws_cloudformation_stack_set.papeis_terraform.name
  stack_set_instance_region = "sa-east-1"

  deployment_targets {
    organizational_unit_ids = [
      aws_organizations_organizational_unit.seguranca.id,
      aws_organizations_organizational_unit.workloads.id,
    ]
  }
}

# O papel de plan (criado no bootstrap) ganha só o direito de entrar no papel de leitura
# das contas-membro.
resource "aws_iam_role_policy" "plan_entra_leitura" {
  name = "entra-papel-leitura-das-contas"
  role = "axiomgo-github-plan"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::*:role/axiomgo-terraform-leitura"
      Condition = {
        StringEquals = { "aws:ResourceOrgID" = aws_organizations_organization.this.id }
      }
    }]
  })
}
