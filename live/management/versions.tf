terraform {
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.70"
    }
  }

  # bucket vem por -backend-config (axiomgo-tfstate-<conta>), criado pelo bootstrap.
  backend "s3" {
    key          = "management/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "sa-east-1"

  default_tags {
    tags = {
      Project    = "axiomgo"
      Env        = "management"
      Owner      = "denis"
      CostCenter = "plataforma"
      ManagedBy  = "terraform"
      Repo       = "RochaDenis/axiomgo-infra"
    }
  }
}
