# Papel de EXECUÇÃO: o ECS usa para baixar a imagem, gravar log e injetar segredo.
resource "aws_iam_role" "execucao" {
  name = "${var.nome}-motor-execucao"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.atual.account_id } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execucao_ecs" {
  role       = aws_iam_role.execucao.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execucao_segredos" {
  name = "le-segredos-do-motor"
  role = aws_iam_role.execucao.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = [var.banco_segredo_arn, aws_secretsmanager_secret.motor.arn]
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = [var.kms_dados_arn, aws_kms_key.app.arn]
      },
    ]
  })
}

# Papel da TAREFA: o que o código do motor pode fazer na AWS. Só os arquivos.
resource "aws_iam_role" "tarefa" {
  name = "${var.nome}-motor-tarefa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.atual.account_id } }
    }]
  })
}

resource "aws_iam_role_policy" "tarefa_arquivos" {
  name = "arquivos-do-cliente"
  role = aws_iam_role.tarefa.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.bucket_arquivos}/*"
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${var.bucket_arquivos}"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.kms_dados_arn
      },
    ]
  })
}
