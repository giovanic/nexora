# Fase 01 — Foundation & Developer Experience

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** NFR-OPS-001, NFR-OPS-002, NFR-OBS-001, NFR-OBS-002, NFR-OBS-004, NFR-SEC-004, NFR-SEC-005
- **ADRs:** [0001](../../architecture/decisions/0001-modular-monolith-monorepo.md), [0002](../../architecture/decisions/0002-technology-baseline.md), [0003](../../architecture/decisions/0003-domain-boundaries-without-engines.md), [0014](../../architecture/decisions/0014-api-contract-tooling.md)

## Objetivo

Ter o esqueleto real do monorepo, com API, web e mobile subindo localmente, serviços conversando e CI com verificações reais, sem nenhuma funcionalidade de negócio.

## Escopo

**Inclui:**

- Monorepo com `apps/api`, `apps/web`, `apps/mobile` e, se justificado, `packages/contracts`.
- Rails em modo API com PostgreSQL, Redis e Sidekiq.
- React com Vite e TypeScript.
- Expo com TypeScript.
- `docker-compose.yml` para os serviços de apoio.
- Linters, tipos e testes básicos.
- Health checks, logs estruturados, monitoramento de erros.
- GitHub Actions.

**Não inclui:** outbox (Fase 02), cadastro, modelos de negócio, integrações externas, telas de produto ou deploy (M1).

## Funcionalidades

- **Versões:** decidir e fixar Ruby, Node, PostgreSQL e Redis ou Valkey, executando uma aplicação mínima. Confirmar a compatibilidade de Ruby e Rails, e de Expo e Node, e atualizar a ADR 0002 e o registro de fontes.
- **Limites de domínio:** estrutura `app/domains/`, com verificação que falha ao violar um limite (ADR 0003).
- **Contrato:** ferramenta de OpenAPI escolhida, com um endpoint de saúde validado no CI e tipos gerados nos dois clientes (ADR 0014).
- **API:** `/health/live` e `/health/ready`, com formato central de erro.
- **Sidekiq:** job de teste executado pelo Redis.
- **Clientes:** web e mobile exibem o estado da API a partir do contrato.
- **Observabilidade:** logs JSON com `correlation_id`, filtro de parâmetros sensíveis e monitoramento de erros nas três aplicações.
- **CI:** todas as etapas de [CI_CD.md](../../engineering/CI_CD.md) que já se apliquem, incluindo o verificador do harness.
- **Documentação:** [LOCAL_DEVELOPMENT.md](../../operations/LOCAL_DEVELOPMENT.md) com comandos testados.

## Dependências

- **Fase 00** concluída, com relatório e `verify-harness.sh` aprovado, com a lacuna do check `scope` aceita pelo responsável em 2026-11-06. A lacuna deixou de existir quando esta fase entrou em desenvolvimento.
- **Decisão do responsável:** primeiro commit, repositório remoto e instalação do `gh`, ou outra forma de operar o GitHub.
- **Pastas geradas já existentes:** `apps/api`, `apps/web`, `apps/mobile` e `packages/contracts` foram criadas em 2026-11-05 por geradores, fora do processo, e o responsável decidiu mantê-las. O plano desta fase decide, item por item, reaproveitar, ajustar ou gerar de novo. O plano desta fase regenerou a API e ajustou os clientes; as divergências de baseline encontradas estão resolvidas na ADR 0002.
- **Fontes a consultar de novo:** todas as versões em [EXTERNAL_SOURCES.md](../../architecture/EXTERNAL_SOURCES.md), incluindo a licença do Redis, ainda não verificada.

## Arquivos e módulos esperados

```text
apps/api/                       Rails API com rspec, rubocop, brakeman
apps/api/app/domains/           Namespaces dos contextos, ainda vazios
apps/web/                       React, Vite, TypeScript, testes
apps/mobile/                    Expo, TypeScript, testes
packages/contracts/             OpenAPI e tipos, se justificado
docker-compose.yml              PostgreSQL e Valkey
.github/workflows/ci.yml        Pipeline
.env.example                    Sem valores reais
```

## Critérios de aceite

- `AC-01-01` (NFR-OPS-001): de um clone limpo, seguindo [LOCAL_DEVELOPMENT.md](../../operations/LOCAL_DEVELOPMENT.md), API, Sidekiq, web e mobile sobem. **Comprovado por:** execução em diretório limpo, com a saída registrada.
- `AC-01-02`: `/health/ready` retorna sucesso com PostgreSQL e Redis, e falha quando um deles é desligado. **Comprovado por:** teste de requisição e demonstração.
- `AC-01-03`: um job enfileirado pela API é processado pelo Sidekiq. **Comprovado por:** teste de integração.
- `AC-01-04`: web e mobile consultam a API usando tipos gerados pelo contrato. **Comprovado por:** teste e captura de tela.
- `AC-01-05` (NFR-OPS-002): o CI executa testes, lint, tipos e o verificador do harness, e falha quando um defeito é plantado em cada aplicação. **Comprovado por:** execuções registradas no GitHub Actions.
- `AC-01-06` (NFR-SEC-004, NFR-SEC-005): o CI executa análise de segurança, auditoria de dependências e varredura de segredos, e falha com um segredo plantado. **Comprovado por:** execução registrada.
- `AC-01-07` (NFR-OBS-001, NFR-OBS-002): logs saem em JSON, com `correlation_id` da requisição ao job, sem parâmetros sensíveis; um erro provocado aparece no monitoramento. **Comprovado por:** teste e demonstração.
- `AC-01-08` (NFR-OBS-004): health checks separam processo vivo de dependências prontas. **Comprovado por:** testes de requisição.
- `AC-01-09`: uma dependência proibida entre dois domínios faz a verificação falhar. **Comprovado por:** violação plantada e removida.
- `AC-01-10`: ADRs 0002, 0003, 0014 e a fila da 0004 atualizadas com decisão e evidência. **Comprovado por:** leitura das ADRs e check `adr`.

## Testes

- Testes de requisição para os health checks, em Rails.
- Teste de integração do job com o Redis real.
- Testes de componente nos dois clientes, cobrindo carregando, sucesso e erro.
- Verificação do contrato.
- Lint de Markdown: avaliar e registrar a decisão.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Incompatibilidade entre Ruby, Rails e gems | Retrabalho | Validar a combinação antes de fixar |
| Expo em WSL e emuladores | Atrito no desenvolvimento | Documentar o caminho testado; usar aparelho físico se preciso |
| Ferramenta de contrato sem manutenção | Dívida | Critérios da ADR 0014 |
| Excesso de infraestrutura cedo | Tempo perdido | Só o que os critérios de aceite exigem |

## Entregáveis

Monorepo funcional, CI verde, documentação de desenvolvimento local atualizada, ADRs decididas e relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais: nenhuma funcionalidade de negócio; `.env.example` sem valores reais.

## Estratégia de revisão

`software-architect` (estrutura, limites), `backend-reviewer` (Rails, Sidekiq), `frontend-mobile-reviewer` (web, Expo), `security-reviewer` (segredos, CI), `qa-reviewer` (evidências). O responsável aprova versões e o relatório.
