# Três camadas por zona:
#   publica - só load balancer e saída NAT
#   app     - servidores (Fargate); saem para a internet só pelo NAT
#   dados   - banco e cache; sem rota para a internet
locals {
  publica = { for i, z in var.zonas : z => cidrsubnet(var.cidr, 8, i) }      # /24
  app     = { for i, z in var.zonas : z => cidrsubnet(var.cidr, 4, 1 + i) }  # /20
  dados   = { for i, z in var.zonas : z => cidrsubnet(var.cidr, 8, 10 + i) } # /24
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.nome }
}

# O grupo padrão da VPC fica sem regra nenhuma: todo recurso usa grupo próprio.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.nome }
}

resource "aws_subnet" "publica" {
  for_each = local.publica

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${var.nome}-publica-${each.key}", Camada = "publica" }
}

resource "aws_subnet" "app" {
  for_each = local.app

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${var.nome}-app-${each.key}", Camada = "app" }
}

resource "aws_subnet" "dados" {
  for_each = local.dados

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value
  tags              = { Name = "${var.nome}-dados-${each.key}", Camada = "dados" }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.nome}-publica" }
}

resource "aws_route" "publica_internet" {
  route_table_id         = aws_route_table.publica.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "publica" {
  for_each = aws_subnet.publica

  subnet_id      = each.value.id
  route_table_id = aws_route_table.publica.id
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.nome}-app" }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table" "dados" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.nome}-dados" }
}

resource "aws_route_table_association" "dados" {
  for_each = aws_subnet.dados

  subnet_id      = each.value.id
  route_table_id = aws_route_table.dados.id
}

# S3 sem passar pelo NAT (gratuito): imagens do ECR e arquivos.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.atual.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.app.id]
  tags              = { Name = "${var.nome}-s3" }
}

data "aws_region" "atual" {}
