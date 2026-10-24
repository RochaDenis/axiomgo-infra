terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
  }

  # Estado no mesmo bucket da conta de gerenciamento, uma chave por camada:
  # um plan de rede nunca toca o banco, e vice-versa.
  backend "s3" {
    key          = "br/teste/dados/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# O número da conta teste-br vem do estado da organização, não de texto solto.
data "terraform_remote_state" "management" {
  backend = "s3"
  config = {
    bucket = var.bucket_estado
    key    = "management/terraform.tfstate"
    region = "sa-east-1"
  }
}

provider "aws" {
  region  = "sa-east-1"
  profile = "teste-br"

  # Falha fechada: o perfil só vale se apontar para a conta teste-br.
  allowed_account_ids = [data.terraform_remote_state.management.outputs.contas["teste-br"]]

  default_tags {
    tags = {
      Project    = "axiomgo"
      Env        = "teste-br"
      Owner      = "denis"
      CostCenter = "celula-br"
      ManagedBy  = "terraform"
      Repo       = "RochaDenis/axiomgo-infra"
    }
  }
}

data "terraform_remote_state" "rede" {
  backend = "s3"
  config = {
    bucket = var.bucket_estado
    key    = "br/teste/rede/terraform.tfstate"
    region = "sa-east-1"
  }
}
