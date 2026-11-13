# 0004 — Eventos de domínio com outbox transacional

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-GAME-001, FR-GAME-002, FR-STRAVA-008, FR-GOALS-007

## Contexto

Gamification, Goals, Notifications e Progress & Analytics reagem a fatos de outros domínios sem depender deles diretamente. Se um evento for perdido, a pessoa perde XP ou uma meta fica errada. Se enfileirarmos um job e a transação falhar, um evento pode descrever algo que não aconteceu.

## Problema

Como comunicar fatos entre domínios sem perder eventos, sem eventos fantasmas e sem efeito duplicado?

## Alternativas

1. **Chamadas síncronas diretas:** simples, mas acoplam os domínios, e uma falha em Gamification derrubaria o registro de refeição.
2. **Enfileirar o job direto do serviço:** simples, mas sem atomicidade com a transação.
3. **Outbox transacional com Sidekiq:** evento gravado na mesma transação, publicado depois, com consumidores idempotentes. Exige tabela e job publicador.
4. **Broker externo (Kafka, RabbitMQ):** recursos avançados, sem necessidade e com alta carga operacional.

## Decisão

**Já vale:** atomicidade entre mudança e evento, entrega pelo menos uma vez e idempotência em cada consumidor. **Fila, decidida na Fase 01 ([ADR 0002](0002-technology-baseline.md)):** Sidekiq com Valkey 9.1, por decisão do responsável em 2026-11-06, com job real processado na validação. A implementação da outbox continua com a Fase 02.

Outbox transacional em `outbox_events`. Entrega pelo menos uma vez. Cada consumidor registra `(consumer, event_id)` em `consumed_events`, na mesma transação do efeito. O formato está no [modelo de domínio](../DOMAIN_MODEL.md).

## Justificativa

É a menor solução que dá atomicidade e reprocessamento, usando só o banco e a fila da stack. Todo evento de domínio passa por ela, por simplicidade. Implementar uma biblioteca própria mínima ou adotar uma pronta é escolha da Fase 02, dona da implementação.

## Consequências

- Consistência eventual: XP pode aparecer segundos depois da ação.
- Consumidores não podem depender de ordem global.
- Precisa de alerta para eventos mortos e rotina de limpeza.
- Testes de idempotência tornam-se obrigatórios para cada consumidor.

## Evidência

Implementação entregue na Fase 02, ainda sem aceitação da ADR:

- **Construído:** `outbox_events` e `consumed_events`; `Shared::Outbox.publish!` (exige transação, filtra o payload), `PublishJob` (entrega após o commit, com a rotina de 1 minuto como rede de segurança), consumidores idempotentes em savepoint junto da linha de `consumed_events`, retentativas com espera crescente e evento morto após 8 falhas com alerta, `ReconcileJob` (acusa consumidor faltante), `CleanupJob` (só eventos publicados, 30 dias após a publicação) e regra de descarte para usuário com exclusão pedida. O procedimento para evento morto está em [RUNBOOK_OUTBOX.md](../../operations/RUNBOOK_OUTBOX.md).
- **AC-02-12:** `apps/api/spec/integration/deletion_requested_delivery_spec.rb` prova que `user.deletion_requested` é entregue mesmo com falha do consumidor, reprocessado sem efeito duplicado, e que a conferência acusa consumidor faltante.
- **Outros specs:** `apps/api/spec/domains/shared/outbox_spec.rb` e `apps/api/spec/domains/shared/outbox/` (publish, reconcile, cleanup e agenda).
- **Revisão:** várias rodadas de revisão por tarefa na Fase 02 corrigiram, entre outros achados, evento marcado como publicado sem o efeito do consumidor e a corrida entre revogação de `health_data` e escrita de perfil.
- **Suíte completa** em 2026-11-13: `583 examples, 0 failures`.

Aceitação pendente do responsável no encerramento da Fase 02. Esta seção não muda o estado da decisão.

## Estado da decisão

Proposta
