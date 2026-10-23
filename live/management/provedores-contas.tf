# Provedores das contas-membro. Cada um usa um perfil AWS que a esteira escreve antes
# do terraform: no plan, o perfil aponta para axiomgo-terraform-leitura; no apply, para
# axiomgo-terraform-escrita. Assim o mesmo plan salvo é aplicado com o papel certo.
# Os números das contas vêm do estado do Terraform (output "contas"), não do nome.
provider "aws" {
  alias   = "logs"
  region  = "sa-east-1"
  profile = "logs"

  # Falha fechada: o perfil só vale se apontar para a conta logs desta organização.
  allowed_account_ids = [aws_organizations_account.conta["logs"].id]

  default_tags {
    tags = {
      Project    = "axiomgo"
      Env        = "logs"
      Owner      = "denis"
      CostCenter = "plataforma"
      ManagedBy  = "terraform"
      Repo       = "RochaDenis/axiomgo-infra"
    }
  }
}

provider "aws" {
  alias   = "seguranca"
  region  = "sa-east-1"
  profile = "seguranca"

  allowed_account_ids = [aws_organizations_account.conta["seguranca"].id]

  default_tags {
    tags = {
      Project    = "axiomgo"
      Env        = "seguranca"
      Owner      = "denis"
      CostCenter = "plataforma"
      ManagedBy  = "terraform"
      Repo       = "RochaDenis/axiomgo-infra"
    }
  }
}
