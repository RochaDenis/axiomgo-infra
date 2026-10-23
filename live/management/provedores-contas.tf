# Provedores das contas-membro. Cada um usa um perfil AWS que a esteira escreve antes
# do terraform: no plan, o perfil aponta para axiomgo-terraform-leitura; no apply, para
# axiomgo-terraform-escrita. Assim o mesmo plan salvo é aplicado com o papel certo.
provider "aws" {
  alias   = "logs"
  region  = "sa-east-1"
  profile = "logs"

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
