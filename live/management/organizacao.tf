resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # Só o que a fase 0 usa. GuardDuty, CloudTrail, Config, Security Hub, Backup e
  # Identity Center são ligados na 0b pelos recursos de cada serviço (a AWS recomenda
  # não habilitar acesso confiável "por fora", via Organizations).
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com", # trilha de auditoria da organização (auditoria.tf)
    "guardduty.amazonaws.com",  # admin delegado do GuardDuty (deteccao.tf)
    "iam.amazonaws.com",        # gestão centralizada do usuário raiz das contas-membro
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

  lifecycle {
    prevent_destroy = true
  }
}

# Contas-membro nascem sem senha nem chave de raiz; tarefas de raiz só pela conta de
# gerenciamento, com sessão curta e auditada.
resource "aws_iam_organizations_features" "raiz_centralizada" {
  enabled_features = ["RootCredentialsManagement", "RootSessions"]

  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_organizational_unit" "seguranca" {
  name      = "Seguranca"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

# As SCPs valem para as contas-membro. A conta de gerenciamento não é afetada por SCP,
# por isso nada roda nela além de organização, custo e identidade.
locals {
  # Papéis que o Terraform usa nas contas-membro para configurar a base de segurança.
  papeis_de_plataforma = [
    "arn:aws:iam::*:role/axiomgo-terraform-*",
    "arn:aws:iam::*:role/OrganizationAccountAccessRole",
    "arn:aws:iam::*:role/stacksets-exec-*", # o StackSet da organização cria os papéis axiomgo-terraform-*
  ]

  # Uma SCP só, com todas as travas: a AWS limita a 5 SCPs por alvo (contando a
  # FullAWSAccess e o freio de gasto) e a 5.120 caracteres por SCP.
  travas = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "NegaForaDasRegioes"
        Effect = "Deny"
        NotAction = [
          "account:*", "acm:*", "aws-marketplace:*", "aws-portal:*", "billing:*",
          "budgets:*", "ce:*", "cloudfront:*", "config:*", "cur:*", "freetier:*",
          "globalaccelerator:*", "health:*", "iam:*", "identitystore:*", "invoicing:*",
          "kms:*", "notifications:*", "organizations:*", "payments:*", "pricing:*",
          "route53:*", "route53domains:*", "s3:GetAccountPublic*", "s3:ListAllMyBuckets",
          "s3:PutAccountPublic*", "savingsplans:*", "shield:*", "sso:*", "sso-directory:*",
          "sts:*", "support:*", "tax:*", "trustedadvisor:*", "waf:*", "wafv2:*",
          "wellarchitected:*",
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = { "aws:RequestedRegion" = var.regioes_permitidas }
        }
      },
      {
        Sid    = "NegaDesligarAuditoriaEDeteccao"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail", "cloudtrail:StopLogging", "cloudtrail:UpdateTrail",
          "config:DeleteConfigurationRecorder", "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "guardduty:DeleteDetector", "guardduty:DisassociateFromAdministratorAccount",
          "guardduty:UpdateDetector",
          "securityhub:DisableSecurityHub", "securityhub:DisassociateFromAdministratorAccount",
          "backup:DeleteBackupVault", "backup:DeleteBackupVaultLockConfiguration",
          "s3:BypassGovernanceRetention", "s3:PutObjectLegalHold", "s3:PutBucketObjectLockConfiguration",
          "kms:ScheduleKeyDeletion",
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = { "aws:PrincipalArn" = local.papeis_de_plataforma }
        }
      },
      {
        Sid    = "ProtegePapeisDePlataforma"
        Effect = "Deny"
        Action = [
          "iam:AttachRolePolicy", "iam:CreateRole", "iam:DeleteRole", "iam:DeleteRolePermissionsBoundary",
          "iam:DeleteRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePermissionsBoundary",
          "iam:PutRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:UpdateAssumeRolePolicy", "iam:UpdateRole",
        ]
        Resource = local.papeis_de_plataforma
        Condition = {
          ArnNotLike = { "aws:PrincipalArn" = local.papeis_de_plataforma }
        }
      },
      {
        Sid    = "ProtegeBucketDaTrilha"
        Effect = "Deny"
        Action = [
          "s3:PutBucket*", "s3:DeleteBucket*", "s3:PutLifecycleConfiguration", "s3:PutEncryptionConfiguration",
          "s3:PutReplicationConfiguration", "s3:PutAccelerateConfiguration", "s3:PutInventoryConfiguration",
        ]
        Resource = ["arn:aws:s3:::axiomgo-cloudtrail-*"]
        Condition = {
          ArnNotLike = { "aws:PrincipalArn" = local.papeis_de_plataforma }
        }
      },
      {
        Sid    = "ProtegeChaveDaTrilha"
        Effect = "Deny"
        Action = [
          "kms:DisableKey", "kms:PutKeyPolicy", "kms:CreateGrant", "kms:RevokeGrant", "kms:DeleteAlias",
          "kms:TagResource", "kms:UntagResource", "kms:ScheduleKeyDeletion", "kms:DisableKeyRotation",
          "kms:UpdateAlias", "kms:UpdateKeyDescription",
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:ResourceTag/Protecao" = "auditoria" }
          ArnNotLike   = { "aws:PrincipalArn" = local.papeis_de_plataforma }
        }
      },
      {
        Sid      = "NegaUsuarioIamComChave"
        Effect   = "Deny"
        Action   = ["iam:CreateUser", "iam:CreateAccessKey"]
        Resource = "*"
      },
      {
        Sid      = "NegaSairDaOrganizacao"
        Effect   = "Deny"
        Action   = "organizations:LeaveOrganization"
        Resource = "*"
      },
      # Sem "nega raiz": as contas-membro já nascem sem credencial de raiz
      # (aws_iam_organizations_features), e uma SCP dessas bloquearia também as
      # sessões de raiz de recuperação feitas pela conta de gerenciamento.
    ]
  }
}

resource "aws_organizations_policy" "travas" {
  name        = "axiomgo-travas"
  description = "Regioes permitidas, auditoria e deteccao protegidas, papeis de plataforma protegidos, sem chave IAM."
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(local.travas)

  depends_on = [aws_organizations_organization.this]
}

resource "aws_organizations_policy_attachment" "travas_raiz" {
  policy_id = aws_organizations_policy.travas.id
  target_id = aws_organizations_organization.this.roots[0].id
}
