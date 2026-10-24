module "dados" {
  source = "../../../../modules/dados"

  nome          = "axiomgo-teste-br"
  vpc_id        = data.terraform_remote_state.rede.outputs.vpc_id
  subnets_dados = data.terraform_remote_state.rede.outputs.subnets_dados
  cidrs_app     = data.terraform_remote_state.rede.outputs.cidrs_app

  # Teste: pausa sozinho sem conexão (cobra só o disco) e não passa de 4 ACU.
  acu_min = 0
  acu_max = 4
  leitor  = false
}
