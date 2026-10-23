# Freio de gasto (decisão do Denis, 23/10/2026): ao bater 100% do orçamento do mês, a AWS
# anexa sozinha uma SCP que impede CRIAR recurso novo nas contas-membro. O que já roda
# continua; banco e backup nunca são tocados. Para soltar: remover o anexo da SCP
# (Budgets → Actions → Reverse) ou aumentar o orçamento por PR.

resource "aws_organizations_policy" "freio" {
  name        = "axiomgo-freio-de-gasto"
  description = "Aplicada pelo orçamento ao atingir 100%: nega criar recurso novo."
  type        = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "FreioDeGasto"
      Effect = "Deny"
      Action = [
        "ec2:RunInstances", "ec2:CreateNatGateway", "ec2:AllocateAddress", "ec2:CreateVpcEndpoint",
        "ecs:CreateService", "ecs:RunTask", "ecs:StartTask",
        "elasticloadbalancing:CreateLoadBalancer",
        "rds:CreateDBCluster", "rds:CreateDBInstance",
        "elasticache:CreateServerlessCache", "elasticache:CreateCacheCluster", "elasticache:CreateReplicationGroup",
        "lambda:CreateFunction", "sagemaker:Create*", "bedrock:CreateProvisionedModelThroughput",
        "eks:CreateCluster", "eks:CreateNodegroup", "redshift:CreateCluster", "opensearch:CreateDomain",
        "es:CreateDomain",
      ]
      Resource = "*"
    }]
  })

  depends_on = [aws_organizations_organization.this]
}

data "aws_iam_policy_document" "freio_confianca" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.atual.account_id]
    }
  }
}

data "aws_iam_policy_document" "freio_permissao" {
  statement {
    actions = [
      "organizations:AttachPolicy", "organizations:DetachPolicy",
      "organizations:DescribePolicy", "organizations:ListTargetsForPolicy",
    ]
    resources = [aws_organizations_policy.freio.arn, "arn:aws:organizations::${data.aws_caller_identity.atual.account_id}:ou/*"]
  }

  # ListPolicies não aceita restrição por recurso.
  statement {
    actions   = ["organizations:ListPolicies"]
    resources = ["*"] #checkov:skip=CKV_AWS_356:ListPolicies só aceita "*"
  }
}

data "aws_caller_identity" "atual" {}

resource "aws_iam_role" "freio" {
  name               = "axiomgo-budgets-freio"
  assume_role_policy = data.aws_iam_policy_document.freio_confianca.json
}

resource "aws_iam_role_policy" "freio" {
  name   = "anexa-scp-de-freio"
  role   = aws_iam_role.freio.id
  policy = data.aws_iam_policy_document.freio_permissao.json
}

resource "aws_budgets_budget_action" "freio" {
  budget_name        = aws_budgets_budget.mensal.name
  action_type        = "APPLY_SCP_POLICY"
  approval_model     = "AUTOMATIC"
  notification_type  = "ACTUAL"
  execution_role_arn = aws_iam_role.freio.arn

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100
  }

  definition {
    scp_action_definition {
      policy_id = aws_organizations_policy.freio.id
      # A API de Budgets só aceita alvo com 12 a 68 caracteres (conta ou OU); a raiz
      # (r-xxxx) é recusada. Todas as contas-membro ficam nestas duas OUs.
      target_ids = [
        aws_organizations_organizational_unit.seguranca.id,
        aws_organizations_organizational_unit.workloads.id,
      ]
    }
  }

  subscriber {
    address           = var.alert_email
    subscription_type = "EMAIL"
  }
}
