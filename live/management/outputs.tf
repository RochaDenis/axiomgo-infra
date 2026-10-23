output "organization_id" {
  description = "ID da organização AWS."
  value       = aws_organizations_organization.this.id
}

output "ou_ids" {
  description = "IDs das unidades organizacionais."
  value = {
    seguranca = aws_organizations_organizational_unit.seguranca.id
    workloads = aws_organizations_organizational_unit.workloads.id
  }
}

output "scp_ids" {
  description = "IDs das SCPs: travas (sempre anexada à raiz) e freio (anexada pelo orçamento a 100%)."
  value = {
    travas = aws_organizations_policy.travas.id
    freio  = aws_organizations_policy.freio.id
  }
}
