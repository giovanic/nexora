# Fase 04 — Strava Integration

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** FR-ACT-001, FR-ACT-002, FR-ACT-003, FR-STRAVA-001, FR-STRAVA-002, FR-STRAVA-003, FR-STRAVA-004, FR-STRAVA-005, FR-STRAVA-006, FR-STRAVA-007, FR-STRAVA-008, FR-STRAVA-009, FR-STRAVA-010, FR-STRAVA-011, FR-STRAVA-012, FR-STRAVA-013, FR-MOBILE-003, NFR-SEC-007, NFR-PRIVACY-006
- **ADRs:** [0008](../../architecture/decisions/0008-strava-data-boundaries.md)
- **Arquitetura:** [STRAVA_INTEGRATION.md](../../architecture/STRAVA_INTEGRATION.md)

## Objetivo

Importar atividades autorizadas de forma confiável, sem duplicar, com todo o ciclo de vida da integração, dentro dos termos e limites do Strava.

## Escopo

**Inclui:** contextos Activities e Strava Integration; registro manual de atividades; OAuth; tokens; webhook; importação; atualização; exclusão; sincronização inicial; reconciliação; limites de requisição; desconexão; telas de conexão e histórico.

**Não inclui:** feed, segmentos, comentários, kudos, leaderboards, escrita no Strava, envio de dados à IA, exibição a outras pessoas. Nem scraping.

## Funcionalidades

Todos os itens de [STRAVA_INTEGRATION.md](../../architecture/STRAVA_INTEGRATION.md):

- **Registro manual** com tipo, data, duração e, opcionalmente, distância e elevação.
- **OAuth** web e mobile, com `state` assinado e tratamento de escopos reduzidos. Escopo pedido: `activity:read`.
- **Tokens** cifrados, com renovação sob bloqueio e salvamento atômico do novo refresh token.
- **Webhook:** validação, resposta em até 2 segundos, processamento assíncrono.
- **Processamento:** criação, atualização, exclusão e revogação pelo atleta. Atividade é sempre buscada na API.
- **Sincronização inicial** em lotes, retomável, com progresso visível. Período inicial definido nesta fase.
- **`RateLimitBudget`** a partir dos headers, com prioridades e tratamento de 429.
- **Reconciliação** diária.
- **Desconexão** com `POST /oauth/revoke`, apagando tokens e dados.
- **Marca:** botão oficial, "View on Strava", "Powered by Strava".
- **Capacidade:** recusar a conexão com mensagem clara ao atingir a capacidade; preparar o pedido de revisão.

## Dependências

- **Fase 02** concluída. A Fase 03 não é necessária.
- **Ações do responsável:** assinatura do Strava, criação da aplicação, upgrade para 10 atletas e, quando precisar, envio do formulário de revisão.
- **Fontes a consultar de novo:** API Agreement vigente, autenticação, webhooks, limites, diretrizes de marca, e a **referência completa da API**, lida só em parte.

## Arquivos e módulos esperados

```text
apps/api/app/domains/activities/
apps/api/app/domains/strava_integration/
apps/api/app/domains/strava_integration/adapters/strava_client.rb
apps/api/app/controllers/webhooks/strava_controller.rb
apps/api/db/migrate/    activities, integrations, integration_tokens, activity_sync_events
apps/mobile/src/features/activities/
apps/mobile/src/features/strava/
```

## Critérios de aceite

- `AC-04-01` (FR-ACT-001, FR-ACT-002): registro manual e histórico com filtros funcionam, com paginação. **Comprovado por:** testes.
- `AC-04-02` (FR-STRAVA-001): a conexão real funciona na aplicação em modo de teste, exige o consentimento `strava_integration`, e escopos reduzidos são tratados. **Comprovado por:** demonstração com a conta do responsável e testes.
- `AC-04-03` (FR-STRAVA-002, NFR-SEC-001): renovações simultâneas fazem uma só chamada, e o novo token é salvo antes do uso; tokens estão cifrados no banco. **Comprovado por:** teste de concorrência e inspeção da coluna.
- `AC-04-04` (FR-STRAVA-003): a validação real da assinatura de webhook é concluída, e cada evento é confirmado em até 2 segundos, sem chamada externa no endpoint. **Comprovado por:** assinatura criada e teste de tempo.
- `AC-04-05` (FR-STRAVA-004, FR-STRAVA-005, FR-STRAVA-006): criar, alterar e apagar uma atividade real no Strava reflete no produto. **Comprovado por:** demonstração registrada e testes com dublê.
- `AC-04-06` (FR-ACT-003, FR-STRAVA-008): reprocessar qualquer evento não duplica nem altera o resultado. **Comprovado por:** testes de idempotência e concorrência.
- `AC-04-07` (FR-STRAVA-007, FR-STRAVA-009): a sincronização inicial é retomada após uma falha, os headers de limite são lidos e o orçamento é respeitado; 429 adia o trabalho sem perda. **Comprovado por:** testes e demonstração.
- `AC-04-08` (FR-STRAVA-010): a reconciliação recupera um evento perdido, e não apaga por ausência na listagem. **Comprovado por:** teste.
- `AC-04-09` (FR-STRAVA-011, FR-STRAVA-012): desconectar, revogar pelo Strava ou revogar o consentimento apaga tokens, dados e eventos relacionados, revogando antes de apagar, com fila de nova tentativa; o formato real do evento fica registrado, e a ADR 0017 está decidida. **Comprovado por:** demonstração real, varredura em teste e teste de falha na revogação.
- `AC-04-10` (FR-STRAVA-013, NFR-PRIVACY-006): dados de um atleta não aparecem para outro nem em nenhuma chamada à IA; as telas seguem as diretrizes. **Comprovado por:** teste com duas contas, verificação de limites de domínio e capturas de tela.
- `AC-04-11` (NFR-SEC-007): evento forjado não cria, altera nem apaga dados. **Comprovado por:** testes com `subscription_id` inválido, atividade inexistente, e `subscription_id` válido com `delete` ou `authorized=false` para uma atividade ou token ainda válidos na API.
- `AC-04-13`: só os campos da lista permitida são gravados, e logs não contêm tokens, código OAuth ou título da atividade. **Comprovado por:** teste com payload contendo rota, coordenadas e título.
- `AC-04-12` (FR-MOBILE-003): o app conecta e mostra atividades, incluindo o estado de sincronização e os três estados de tela. **Comprovado por:** testes e demonstração.

## Testes

Conforme [TESTING_STRATEGY.md](../../engineering/TESTING_STRATEGY.md). Dublês baseados no formato oficial, mais demonstrações reais registradas. Eventos fora de ordem e múltiplos eventos para o mesmo objeto. Token revogado (`401`).

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Strava não autoriza mais de 10 atletas | Sem escala | Beta sem Strava; webhooks; backfill limitado; pedido com antecedência |
| Produto entendido como réplica | Perda de acesso | Sem funções sociais; revisar telas contra o termo |
| Limite diário baixo para muitos backfills | Sincronização lenta | Período limitado e fila com orçamento |
| Perda do refresh token por falha | Reconexão manual | Salvamento atômico e estado `error` |
| Mudança nos termos | Reavaliação | Nova consulta a cada fase que use Strava |
| Evento forjado sem assinatura | Ruído e custo | Sempre buscar na API; `subscription_id`; limite de requisições |

## Entregáveis

Contextos, telas, assinatura de webhook, documentação operacional da aplicação Strava, registro de fontes atualizado, relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais: evidência de conexão real com o Strava, além dos testes com dublê.

## Estratégia de revisão

`security-reviewer` (tokens, webhook, termos), `backend-reviewer` (jobs, concorrência), `software-architect` (fronteira entre Strava Integration e Activities), `frontend-mobile-reviewer`, `qa-reviewer`. O responsável aprova as telas para o pedido de revisão e o relatório.
