module "rede" {
  source = "../../../../modules/rede"

  nome  = "axiomgo-teste-br"
  cidr  = "10.20.0.0/16" # prod-br: 10.21.0.0/16
  zonas = ["sa-east-1a", "sa-east-1c"]
  saida = "nat_instancia"
}
