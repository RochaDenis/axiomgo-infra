# axiomgo-infra

Infraestrutura AWS do AxiomGO em Terraform. Plataforma **B2B** (dado no país), Brasil primeiro.
Spec e padrão de segurança: `RochaDenis/ST-Operations-os` → `docs/infra/2026-10-20-multi-regiao-nuvem/`.

## Regras

- Toda mudança é PR. O GitHub Actions faz checagens e `plan`; o `apply` só roda no `main`,
  aplica **o plan revisado** e espera a aprovação do Denis no environment `management`.
- Nenhuma chave de acesso fixa. GitHub → AWS por OIDC (papéis `axiomgo-github-plan` e `axiomgo-github-apply`).
- O Claude nunca tem credencial AWS: escreve código e abre PR.
- Estado no S3 `axiomgo-tfstate-<conta>`, versionado, criptografado, com trava nativa.

## Estrutura

```
bootstrap/bootstrap.yaml     # roda UMA vez no CloudShell (estado + OIDC)
live/management/             # organização, SCPs, orçamento, auditoria e detecção
live/br/teste/rede/          # rede da célula Brasil na conta teste-br
live/br/teste/dados/         # banco, cache e arquivos da célula Brasil (teste-br)
modules/rede/                # VPC em 3 camadas (pública, app, dados), NAT e flow logs
modules/dados/               # Aurora PostgreSQL 16 Serverless v2, Valkey Serverless, S3 de arquivos, KMS
.github/workflows/terraform.yml
```

## Arranque (uma vez só)

1. Console AWS → região **São Paulo (sa-east-1)** → ícone **CloudShell** (barra de cima).
2. No CloudShell: **Actions → Upload file** → envie `bootstrap/bootstrap.yaml`.
3. Rode:
   ```bash
   aws cloudformation deploy --template-file bootstrap.yaml --stack-name axiomgo-bootstrap \
     --capabilities CAPABILITY_NAMED_IAM --region sa-east-1
   aws sts get-caller-identity --query Account --output text
   ```
4. No GitHub (`Settings` deste repositório):
   - **Secrets and variables → Actions → Variables**: `AWS_ACCOUNT_ID` = número do passo 3.
   - **Environments → New environment** `management` → **Required reviewers**: Denis.
5. Merge no `main` → o Actions roda checagens, plan e aplica sozinho **se o plan só cria ou altera**. Se o plan apagar ou recriar qualquer recurso, o apply para; só o Denis libera em **Run workflow** com `permitir_destruicao = sim`.

## O que já existe

| Item | Onde |
| --- | --- |
| Orçamento US$ 200/mês, avisos 50/80/100% e previsão de estouro | `live/management/custo.tf` |
| Alerta de anomalia de custo: a AWS cria sozinha ao ativar o Cost Explorer (1 clique no console) | console |
| **Freio:** a 100% do orçamento, SCP automática impede criar recurso novo (o que roda continua; banco intocado) | `live/management/freio.tf` |
| AWS Organizations + OUs `Seguranca` e `Workloads` | `live/management/organizacao.tf` |
| SCP única `axiomgo-travas`: só `sa-east-1`/`us-east-1`/`eu-central-1`; não desliga auditoria/detecção; papéis de plataforma protegidos; sem usuário IAM com chave; não sai da organização | `live/management/organizacao.tf` |
| Raiz centralizada: contas-membro sem senha/chave de raiz | `live/management/organizacao.tf` |
| Contas-membro `seguranca`, `logs` (OU Seguranca), `teste-br`, `prod-br` (OU Workloads) | `live/management/contas.tf` |
| Papéis `axiomgo-terraform-leitura` (plan) e `-escrita` (apply) em cada conta-membro, via StackSet | `live/management/papeis-contas.tf` |
| Trilha de auditoria da organização na conta `logs`: KMS, validação de integridade, retenção travada 1 ano | `live/management/auditoria.tf` |
| GuardDuty em todas as contas (admin delegado: `seguranca`), proteção de S3 e de banco | `live/management/deteccao.tf` |

| Rede do `teste-br`: VPC `10.20.0.0/16` em 2 zonas, camadas pública/app/dados, instância NAT, flow logs criptografados | `live/br/teste/rede` |
| Dados do `teste-br`: Aurora PostgreSQL 16 Serverless v2 (pausa sozinho, máx. 4 ACU, TLS obrigatório, senha gerida pela AWS), Valkey Serverless (teto 1 GB), bucket de arquivos; tudo com chave KMS da célula, sem acesso público | `live/br/teste/dados` |

## Pilhas

Cada pasta em `live/` tem estado próprio (`<pasta>/terraform.tfstate` no bucket de estado). A esteira roda o plan de todas e aplica uma por vez, na ordem da lista `stack` do workflow. Pilha nova entra nas duas listas.

## Próximas PRs

- 0b-3: Security Hub CSPM + novo Security Hub, Config (admin delegado na conta `seguranca`), IAM Access Analyzer, monitor de anomalia por conta, alertas no Discord.
- 0c: IAM Identity Center com MFA (ativação da instância é 1 clique no console).
- 1: módulos `computacao` (ECS, ECR) e `borda` (ALB, WAF) no `teste-br`.
