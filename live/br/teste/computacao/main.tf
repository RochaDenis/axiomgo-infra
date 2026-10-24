module "computacao" {
  source = "../../../../modules/computacao"

  nome              = "axiomgo-teste-br"
  kms_dados_arn     = data.terraform_remote_state.dados.outputs.kms_dados_arn
  banco_segredo_arn = data.terraform_remote_state.dados.outputs.banco_segredo_arn
  bucket_arquivos   = data.terraform_remote_state.dados.outputs.bucket_arquivos
}
