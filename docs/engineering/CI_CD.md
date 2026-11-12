# CI/CD

> O pipeline está em [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). O deploy entra no [M1](../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md).

## Plataforma

GitHub Actions, conforme a stack de referência, no repositório público `giovanic/nexora`. Em repositório público, os runners padrão são gratuitos e a proteção de branch está disponível. Por isso, nada plantado em uma prova pode ser um segredo real: PRs e execuções ficam visíveis.

## Pipeline

Roda em todo pull request e na branch principal. O CI executa verificações reais: nenhuma etapa pode ser marcada para continuar em caso de erro.

| Job | Etapa | O que faz | Bloqueia |
|---|---|---|---|
| `harness` | Harness | `scripts/test-verify-harness.sh` e `scripts/verify-harness.sh` | Sim |
| `secrets` | Segredos | Gitleaks 8.30.1, com checksum conferido, no histórico de **todas** as branches | Sim |
| `api` | Lint | RuboCop | Sim |
| `api` | Segurança | Brakeman `-w2` (confiança média ou alta) e `bundle-audit` | Sim, em qualquer aviso do Brakeman ou vulnerabilidade conhecida |
| `api` | Testes | RSpec com PostgreSQL e Valkey reais em serviço, e um processo `sidekiq` real | Sim |
| `api` | Limites | `spec/architecture`, dentro do RSpec | Sim |
| `api` | Contrato | Respostas reais contra o OpenAPI, e rotas contra `paths`, dentro do RSpec | Sim |
| `contracts` | Tipos gerados | Falha se os tipos versionados diferem do que o contrato gera | Sim |
| `web` | Auditoria JS | `npm audit --audit-level=high`, sobre o lockfile do monorepo | Sim, em achado alto |
| `web` | Tipos, lint, testes, build | `tsc`, ESLint sem nenhum aviso, Vitest, Vite | Sim |
| `mobile` | Tipos, lint, testes | `tsc`, ESLint sem nenhum aviso, `jest-expo` | Sim |

**Etapa de migrations:** rodar e reverter em banco limpo entra na primeira fase que criar uma migration. Hoje nada provaria.

**Sem filtros por caminho:** todos os jobs rodam em todo pull request.

**Lint de Markdown:** não adotado. O verificador do harness já impõe o formato que importa, e um linter acrescentaria uma dependência sem proteger nenhum critério.

**Limite do Gitleaks:** como ele varre todas as branches, um segredo em uma branch qualquer reprova `secrets` em todos os pull requests até a branch ser apagada. Isso é intencional em um repositório público, e foi observado na prova da Fase 01.

## Prova de que o CI reprova

Na Fase 01, um defeito plantado por vez, em PR descartável, reprovou o job esperado. Os links estão no relatório da fase, `docs/roadmap/reports/PHASE_01_REPORT.md`.

## Proteção de `main`

`main` exige os seis jobs verdes, e branch atualizada antes do merge. Sem exigência de aprovação por outra pessoa, porque o desenvolvedor é único.

## Regras

- **Sem segredos reais no CI** para testes. APIs externas usam dublês.
- **Versões iguais às do ambiente local** e fixadas conforme a [ADR 0002](../architecture/decisions/0002-technology-baseline.md).
- **Ações do GitHub fixadas** por hash de commit, conferido na fonte.
- **Permissões mínimas** para o token do workflow.
- **Teste instável se corrige ou se remove com registro.** Não se ignora.
- O desenvolvedor é único, mas a branch principal segue protegida por CI verde.

## Deploy (a partir do M1)

Depende da [ADR 0015](../architecture/decisions/0015-hosting-and-deployment.md).

Requisitos, qualquer que seja o provedor:

1. Deploy a partir de um commit que passou no CI.
2. Migrations seguras, executadas de forma controlada.
3. Verificação do `/health/ready` após o deploy.
4. Caminho documentado de reversão, testado ao menos uma vez.
5. Segredos no gerenciador da plataforma.

## Mobile

Build e distribuição definidos no M1, com builds internos para o beta. O uso de EAS ou de outra ferramenta é avaliado, com custo.

## Avaliação de IA

Fora do pipeline comum, porque custa dinheiro. Executada manualmente ou por gatilho explícito.
