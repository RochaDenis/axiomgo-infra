# Detecção de ameaças: GuardDuty com administração delegada na conta "seguranca",
# ligado sozinho em todas as contas da organização (atuais e futuras), em sa-east-1.
# A AWS exige o GuardDuty ligado na conta de gerenciamento antes de nomear a
# administradora delegada (sem ele: BadRequestException "invalid or out-of-range value").
resource "aws_guardduty_detector" "gerenciamento" {
  #checkov:skip=CKV2_AWS_3:A configuração da organização fica na conta seguranca (admin delegado), em aws_guardduty_organization_configuration.todas.
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_organization_admin_account" "seguranca" {
  admin_account_id = aws_organizations_account.conta["seguranca"].id

  depends_on = [
    aws_organizations_organization.this,
    aws_guardduty_detector.gerenciamento,
  ]
}

resource "aws_guardduty_detector" "seguranca" {
  provider = aws.seguranca

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_organization_configuration" "todas" {
  provider = aws.seguranca

  detector_id                      = aws_guardduty_detector.seguranca.id
  auto_enable_organization_members = "ALL"

  depends_on = [aws_guardduty_organization_admin_account.seguranca]
}

resource "aws_guardduty_organization_configuration_feature" "recursos" {
  provider = aws.seguranca
  # Sem EBS_MALWARE_PROTECTION: a plataforma roda em Fargate (sem discos EBS), e o
  # recurso exige acesso confiável extra na organização. O equivalente para contêineres
  # (RUNTIME_MONITORING com agente no Fargate) entra junto com a célula Brasil.
  for_each = toset(["S3_DATA_EVENTS", "RDS_LOGIN_EVENTS"])

  detector_id = aws_guardduty_detector.seguranca.id
  name        = each.key
  auto_enable = "ALL"

  depends_on = [aws_guardduty_organization_configuration.todas]
}
