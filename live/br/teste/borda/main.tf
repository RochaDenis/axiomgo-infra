module "borda" {
  source = "../../../../modules/borda"

  nome             = "axiomgo-teste-br"
  dominio          = "api-br-develop.axiomgo.io" # segue o ramo develop
  vpc_id           = data.terraform_remote_state.rede.outputs.vpc_id
  subnets_publicas = data.terraform_remote_state.rede.outputs.subnets_publicas
  cidrs_app        = data.terraform_remote_state.rede.outputs.cidrs_app
}
