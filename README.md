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
live/management/             # organização, SCPs, orçamento e anomalia de custo
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
5. Merge da PR inicial → o Actions cria organização, SCPs, orçamento e alerta de anomalia.

## O que já existe

| Item | Onde |
| --- | --- |
| Orçamento US$ 200/mês, avisos 50/80/100% e previsão de estouro | `live/management/custo.tf` |
| Alerta diário de gasto fora do padrão por conta (≥ US$ 20); o monitor por serviço a AWS cria sozinha | `live/management/custo.tf` |
| **Freio:** a 100% do orçamento, SCP automática impede criar recurso novo (o que roda continua; banco intocado) | `live/management/freio.tf` |
| AWS Organizations + OUs `Seguranca` e `Workloads` | `live/management/organizacao.tf` |
| SCP única `axiomgo-travas`: só `sa-east-1`/`us-east-1`/`eu-central-1`; não desliga auditoria/detecção; papéis de plataforma protegidos; sem usuário IAM com chave; não sai da organização | `live/management/organizacao.tf` |
| Raiz centralizada: contas-membro sem senha/chave de raiz | `live/management/organizacao.tf` |

## Próximas PRs

- 0b: contas-membro (`seguranca`, `logs`, `teste`, `prod`), CloudTrail da organização, GuardDuty, Security Hub, Config.
- 0c: IAM Identity Center com MFA (ativação da instância é 1 clique no console).
- 1: módulos `rede`, `dados`, `computacao`, `borda`.
