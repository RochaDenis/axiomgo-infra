# Aurora PostgreSQL 16 Serverless v2 + pgvector. Sem endereço público; só os
# servidores (sub-redes de app) chegam na porta 5432, e só com TLS.
data "aws_rds_engine_version" "pg16" {
  engine  = "aurora-postgresql"
  version = "16"
  latest  = true
}

resource "aws_db_subnet_group" "this" {
  name       = var.nome
  subnet_ids = var.subnets_dados
}

resource "aws_security_group" "banco" {
  name        = "${var.nome}-banco"
  description = "Aurora: so os servidores da celula, porta 5432"
  vpc_id      = var.vpc_id

  ingress {
    description = "Postgres a partir das sub-redes de app"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.cidrs_app
  }
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.nome}-pg16"
  family      = "aurora-postgresql16"
  description = "TLS obrigatorio e log de conexoes"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  # Registra mudança de esquema e consulta lenta. Não registra toda consulta:
  # o texto da consulta carrega dado do cliente.
  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "2000"
  }
}

resource "aws_rds_cluster" "this" {
  #checkov:skip=CKV_AWS_327:Criptografado com a chave KMS própria da célula (kms_key_id).
  #checkov:skip=CKV2_AWS_8:Backup automático do Aurora (7 dias); AWS Backup com cofre isolado entra na fase 6.
  #checkov:skip=CKV2_AWS_27:Log de toda consulta grava dado do cliente; registra só DDL e consulta lenta.
  cluster_identifier = var.nome
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = data.aws_rds_engine_version.pg16.version_actual
  database_name      = "axiomgo"
  master_username    = "axiomgo_admin"

  # Senha criada e girada pela AWS no Secrets Manager; nunca passa pelo estado.
  manage_master_user_password   = true
  master_user_secret_kms_key_id = aws_kms_key.dados.arn

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.banco.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  storage_encrypted = true
  kms_key_id        = aws_kms_key.dados.arn

  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]

  backup_retention_period   = var.retencao_backup_dias
  preferred_backup_window   = "06:00-07:00" # 03h-04h em Brasília
  copy_tags_to_snapshot     = true
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.nome}-final"

  serverlessv2_scaling_configuration {
    min_capacity             = var.acu_min
    max_capacity             = var.acu_max
    seconds_until_auto_pause = var.acu_min == 0 ? 600 : null
  }

  tags = { Dado = "cliente" }

  lifecycle {
    prevent_destroy = true
    # Versão menor sobe sozinha (auto_minor_version_upgrade); o código não briga com ela.
    ignore_changes = [engine_version]
  }
}

resource "aws_rds_cluster_instance" "this" {
  #checkov:skip=CKV_AWS_118:Monitoramento avançado cobra por instância; Performance Insights cobre.
  count = var.leitor ? 2 : 1

  identifier                   = "${var.nome}-${count.index}"
  cluster_identifier           = aws_rds_cluster.this.id
  instance_class               = "db.serverless"
  engine                       = aws_rds_cluster.this.engine
  engine_version               = aws_rds_cluster.this.engine_version
  db_subnet_group_name         = aws_db_subnet_group.this.name
  auto_minor_version_upgrade   = true
  performance_insights_enabled = true
  # Performance Insights criptografado com a mesma chave do dado.
  performance_insights_kms_key_id = aws_kms_key.dados.arn
  monitoring_interval             = 0
  copy_tags_to_snapshot           = true

  lifecycle {
    ignore_changes = [engine_version]
  }
}
