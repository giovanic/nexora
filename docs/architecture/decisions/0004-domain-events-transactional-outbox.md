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

**Fila, decidida na Fase 01 ([ADR 0002](0002-technology-baseline.md)):** Sidekiq com Valkey 9.1, por decisão do responsável em 2026-11-06.

Outbox transacional em `outbox_events`, com implementação mínima própria em `Shared::Outbox`, sem gem de outbox. Entrega pelo menos uma vez. Cada consumidor registra `(consumer, event_id)` em `consumed_events`, na mesma transação do efeito. O formato está no [modelo de domínio](../DOMAIN_MODEL.md).

Alternativa considerada: adotar uma gem de outbox pronta. Foi descartada porque o que precisamos cabe em uma tabela, um job publicador e uma regra de descarte, e uma gem traria mais superfície e dependência nova do que esse mínimo.

Regras que todo consumidor futuro deve seguir:

- **Roda dentro da transação que trava o evento.** O `PublishJob` trava o evento com `FOR UPDATE SKIP LOCKED` e executa cada consumidor em um savepoint. Por isso o consumidor só grava nas tabelas do próprio contexto. Chamada externa (e-mail, push, API de terceiros) vai para um job enfileirado, nunca é feita no consumidor.
- **Pelo menos uma vez, sem ordem.** Nem global, nem por pessoa: dois eventos da mesma pessoa podem chegar trocados, e o consumidor tem de ser idempotente e tolerar isso.
- **Tentativas contam por evento** (R14), não por consumidor. Na oitava falha o evento morre (`dead_at`) e dispara alerta.
- **Evento morto nunca é apagado** (R36). A limpeza só remove eventos publicados, 30 dias depois da publicação; o procedimento para reprocessar está em [RUNBOOK_OUTBOX.md](../../operations/RUNBOOK_OUTBOX.md).
- **Payload sem dado pessoal nem de saúde** (R3): identificadores e valores de lista fechada. O evento sobrevive à revogação e não é exportado, então o consumidor lê o restante pela `<Contexto>::Api`.
- **Gancho `discard_if` (R4).** Um contexto registra uma regra que descarta, sem entregar, os eventos que não devem mais ser entregues. Hoje só Identity registra: descarta os eventos de quem pediu a exclusão, travando a linha da pessoa em `users` com `FOR SHARE` para que o pedido não conclua entre a checagem e o consumidor (R40). `user.deletion_requested` nunca é descartado, e é o único nome de evento de Identity que `shared/` conhece (exceção aceita). Acopla a entrega ao estado de Identity: uma regra lenta ou com erro atrasa a entrega.
- **Consulta `undelivered?` (R34).** `Shared::Outbox.undelivered?(name:, user_id:, payload:)` diz se há evento ainda não entregue. Identity a usa para recusar novo consentimento de `health_data` enquanto um `consent.revoked` da pessoa não foi entregue. Acopla a concessão ao andamento da outbox: um evento morto bloqueia o consentimento até o reprocessamento manual.

## Justificativa

É a menor solução que dá atomicidade e reprocessamento, usando só o banco e a fila da stack. Todo evento de domínio passa por ela, por simplicidade.

## Consequências

- Consistência eventual: XP pode aparecer segundos depois da ação.
- Consumidores não podem depender de ordem, global ou por pessoa.
- Consumidor lento segura a trava do evento e, com a regra de descarte, a linha da pessoa; trabalho pesado vai para job.
- Precisa de alerta para eventos mortos e rotina de limpeza, que não apaga os mortos: eles se acumulam até alguém resolver.
- Testes de idempotência tornam-se obrigatórios para cada consumidor.

## Evidência

Implementação entregue na Fase 02:

- **Escolha de implementação:** implementação mínima própria, em `Shared::Outbox`, sem gem de outbox.
- **Construído:** `outbox_events` e `consumed_events`; `Shared::Outbox.publish!` (exige transação, filtra o payload), `PublishJob` (entrega após o commit, com a rotina de 1 minuto como rede de segurança), consumidores idempotentes em savepoint junto da linha de `consumed_events`, retentativas com espera crescente e evento morto após 8 falhas com alerta, `ReconcileJob` (acusa consumidor faltante), `CleanupJob` (só eventos publicados, 30 dias após a publicação) e regra de descarte para usuário com exclusão pedida. O procedimento para evento morto está em [RUNBOOK_OUTBOX.md](../../operations/RUNBOOK_OUTBOX.md).
- **AC-02-12:** `apps/api/spec/integration/deletion_requested_delivery_spec.rb` prova que `user.deletion_requested` é entregue mesmo com falha do consumidor, reprocessado sem efeito duplicado, e que a conferência acusa consumidor faltante.
- **Outros specs:** `apps/api/spec/domains/shared/outbox_spec.rb` e `apps/api/spec/domains/shared/outbox/` (publish, reconcile, cleanup e agenda).
- **Revisão:** várias rodadas de revisão por tarefa na Fase 02 corrigiram, entre outros achados, evento marcado como publicado sem o efeito do consumidor e a corrida entre revogação de `health_data` e escrita de perfil.
- **Suíte completa** em 2026-11-13: `583 examples, 0 failures`.

Aceita pelo responsável em 2026-11-13, no encerramento da Fase 02.

## Estado da decisão

Aceita
