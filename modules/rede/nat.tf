# Saída para a internet das sub-redes de app (o motor chama a IA no OpenRouter).
# Uma saída só, na primeira zona: se a zona cair, a saída cai junto — aceito por custo.

# --- prod: NAT Gateway gerenciado ------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.saida == "nat_gateway" ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.nome}-nat" }
}

resource "aws_nat_gateway" "this" {
  count = var.saida == "nat_gateway" ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.publica[var.zonas[0]].id
  tags          = { Name = var.nome }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "app_nat_gateway" {
  count = var.saida == "nat_gateway" ? 1 : 0

  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

# --- teste: instância NAT (Amazon Linux 2023 + iptables, receita da documentação AWS) ---
data "aws_ami" "al2023_arm" {
  count       = var.saida == "nat_instancia" ? 1 : 0
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-arm64"]
  }
}

resource "aws_security_group" "nat" {
  count = var.saida == "nat_instancia" ? 1 : 0

  name        = "${var.nome}-nat"
  description = "Instancia NAT: entra so das sub-redes de app, sai para a internet"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      description = "HTTP/HTTPS das sub-redes de app"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = values(local.app)
    }
  }

  # Só web: OpenRouter, Clerk, ECR e pacotes do sistema. DNS usa o resolvedor da VPC.
  dynamic "egress" {
    for_each = [80, 443]
    content {
      description = "Saida HTTP/HTTPS para a internet"
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] #trivy:ignore:AVD-AWS-0104 -- e a funcao do NAT
    }
  }
}

resource "aws_iam_role" "nat" {
  count = var.saida == "nat_instancia" ? 1 : 0

  name = "${var.nome}-nat"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

# Só o Systems Manager: atualização de pacotes e acesso de emergência sem SSH.
resource "aws_iam_role_policy_attachment" "nat_ssm" {
  count = var.saida == "nat_instancia" ? 1 : 0

  role       = aws_iam_role.nat[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "nat" {
  count = var.saida == "nat_instancia" ? 1 : 0

  name = "${var.nome}-nat"
  role = aws_iam_role.nat[0].name
}

resource "aws_instance" "nat" {
  count = var.saida == "nat_instancia" ? 1 : 0

  #checkov:skip=CKV_AWS_88:instancia NAT precisa de IP publico
  #checkov:skip=CKV_AWS_126:monitoramento detalhado custa mais que a instancia; teste
  #checkov:skip=CKV_AWS_135:t4g.nano ja e otimizada para EBS por padrao
  ami                         = data.aws_ami.al2023_arm[0].id
  instance_type               = "t4g.nano"
  subnet_id                   = aws_subnet.publica[var.zonas[0]].id
  vpc_security_group_ids      = [aws_security_group.nat[0].id]
  associate_public_ip_address = true #trivy:ignore:AVD-AWS-0164 -- e a funcao do NAT
  source_dest_check           = false
  iam_instance_profile        = aws_iam_instance_profile.nat[0].name

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf install -y iptables-services
    systemctl enable --now iptables
    echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/90-nat.conf
    sysctl --system
    IF=$(ip route show default | awk '{print $5; exit}')
    iptables -t nat -A POSTROUTING -o "$IF" -j MASQUERADE
    iptables -F FORWARD
    service iptables save
  EOT

  tags = { Name = "${var.nome}-nat" }

  lifecycle {
    # AMI nova não recria a instância; atualização é pelo dnf.
    ignore_changes = [ami]
  }
}

resource "aws_route" "app_nat_instancia" {
  count = var.saida == "nat_instancia" ? 1 : 0

  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}
