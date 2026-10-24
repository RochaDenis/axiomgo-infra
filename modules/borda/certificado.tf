# Certificado do endereço público. A validação é por um registro DNS que o Denis
# cria uma vez (o DNS de axiomgo.io fica fora da AWS). Enquanto o certificado não
# for emitido, o load balancer só responde redirecionando para HTTPS.
resource "aws_acm_certificate" "this" {
  domain_name       = var.dominio
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}
