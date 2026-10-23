resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "account.amazonaws.com",
    "backup.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
  ]

  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

  lifecycle {
    prevent_destroy = true
  }
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
  ]

  scps = {
    regioes-permitidas = {
      descricao = "Nega criar recurso fora das regiões permitidas (dado no país)."
      politica = {
        Version = "2012-10-17"
        Statement = [{
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
        }]
      }
    }

    protege-base-de-seguranca = {
      descricao = "Nega desligar auditoria e detecção, criar usuário com chave e sair da organização."
      politica = {
        Version = "2012-10-17"
        Statement = [
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
        ]
      }
    }

    nega-usuario-raiz = {
      descricao = "Nega o uso do usuário raiz nas contas-membro."
      politica = {
        Version = "2012-10-17"
        Statement = [{
          Sid      = "NegaRaiz"
          Effect   = "Deny"
          Action   = "*"
          Resource = "*"
          Condition = {
            StringLike = { "aws:PrincipalArn" = "arn:aws:iam::*:root" }
          }
        }]
      }
    }
  }
}

resource "aws_organizations_policy" "scp" {
  for_each = local.scps

  name        = "axiomgo-${each.key}"
  description = each.value.descricao
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode(each.value.politica)
}

resource "aws_organizations_policy_attachment" "raiz" {
  for_each = aws_organizations_policy.scp

  policy_id = each.value.id
  target_id = aws_organizations_organization.this.roots[0].id
}
