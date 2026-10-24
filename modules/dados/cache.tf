# ElastiCache Serverless (Valkey): cache e filas leves do motor. Pode ser recriado
# sem perda; TLS sempre ligado no serverless. Teto de memória limita o custo.
resource "aws_security_group" "cache" {
  name        = "${var.nome}-cache"
  description = "Valkey: so os servidores da celula, porta 6379"
  vpc_id      = var.vpc_id

  ingress {
    description = "Valkey a partir das sub-redes de app"
    from_port   = 6379
    to_port     = 6380
    protocol    = "tcp"
    cidr_blocks = var.cidrs_app
  }
}

resource "aws_elasticache_serverless_cache" "this" {
  name                 = var.nome
  engine               = "valkey"
  major_engine_version = "8"
  description          = "Cache do motor - ${var.nome}"

  kms_key_id         = aws_kms_key.dados.arn
  security_group_ids = [aws_security_group.cache.id]
  subnet_ids         = var.subnets_dados

  daily_snapshot_time      = "07:00"
  snapshot_retention_limit = 1

  cache_usage_limits {
    data_storage {
      maximum = var.cache_gb_max
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000
    }
  }
}
