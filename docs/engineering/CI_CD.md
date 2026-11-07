# CI/CD

> **Nenhum workflow existe ainda.** Este é o pipeline planejado. A Fase 01 cria os workflows, e o deploy entra no [M1](../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md).

## Plataforma

GitHub Actions, conforme a stack de referência.

**Pendências da máquina atual:** o repositório ainda não tem commits nem remoto, e o `gh` não está instalado. A Fase 01 resolve isso com o responsável, que também decide o primeiro commit.

## Pipeline planejado

Roda em todo pull request e na branch principal. O CI executa verificações reais: nenhuma etapa pode ser marcada para continuar em caso de erro.

| Etapa | O que faz | Bloqueia |
|---|---|---|
| Harness | `scripts/test-verify-harness.sh` e `scripts/verify-harness.sh` | Sim |
| Segredos | Varredura no repositório | Sim |
| API: lint | RuboCop | Sim |
| API: segurança | Brakeman e auditoria de gems | Sim, em achado alto |
| API: testes | RSpec com PostgreSQL e Redis reais em serviço | Sim |
| API: limites | Verificação de dependências entre domínios | Sim |
| API: contrato | Implementação contra o OpenAPI | Sim |
| Web: tipos e lint | Verificação de tipos e ESLint | Sim |
| Web: testes | Componentes | Sim |
| Web: build | Build de produção | Sim |
| Mobile: tipos e lint | Verificação de tipos e ESLint | Sim |
| Mobile: testes | Componentes | Sim |
| JS: auditoria | Auditoria de dependências | Sim, em achado alto |
| Migrations | Rodar e reverter em banco limpo | Sim |

Filtros por caminho podem pular etapas de aplicações não alteradas, mas a etapa do harness sempre roda.

## Regras

- **Sem segredos reais no CI** para testes. APIs externas usam dublês.
- **Versões iguais às do ambiente local** e fixadas conforme a [ADR 0002](../architecture/decisions/0002-technology-baseline.md).
- **Ações do GitHub fixadas** por versão ou commit.
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
