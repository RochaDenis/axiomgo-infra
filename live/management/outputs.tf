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
  description = "IDs das SCPs anexadas à raiz."
  value       = { for k, p in aws_organizations_policy.scp : k => p.id }
}
