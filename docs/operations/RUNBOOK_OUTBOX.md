# Runbook: evento morto na outbox

Quando um evento da outbox falha 8 vezes (cerca de duas horas de tentativas), ele recebe `dead_at` e deixa de ser entregue. A rotina de limpeza **nunca apaga eventos mortos**: eles não foram processados, e alguém precisa resolvê-los.

## Como o alerta aparece

- **Sentry:** uma exceção `DeadEvent`, com duas tags: `outbox_event` (nome do evento, por exemplo `consent.revoked`) e `outbox_consumer` (consumidor que falhou, por exemplo `user_profile.erase_health_data`). O alerta não traz usuário, payload nem mensagem da exceção original.
- **Log do worker:** a cada falha, uma linha `outbox delivery failed event_id=<id> event=<nome> consumer=<consumidor> error=<Classe>`. Só identificadores e a classe do erro; a mensagem pode ter dado de pessoa e não é registrada.

## Inspecionar sem expor dados

No console (`bin/rails console`), sempre por id do evento, sem imprimir `payload` nem `user_id`:

```ruby
id = "<event_id do log>"
Shared::Outbox::Event.where(id:).pluck(:name, :version, :attempts, :occurred_at, :dead_at)
Shared::Outbox::ConsumedEvent.where(event_id: id).pluck(:consumer, :consumed_at)  # consumidores que já aplicaram
```

Nunca use `Event.find(id)` ou `inspect` na sessão: isso imprime o payload. Procure a causa pela classe do erro nos logs do worker (`event_id=<id>`), e reproduza com um usuário de teste, nunca com dado real.

## Reenfileirar (causa corrigida)

Depois de corrigir a causa (código, indisponibilidade de serviço), devolva o evento à fila. Consumidores que já aplicaram são pulados, então reentregar é seguro.

```ruby
id = "<event_id>"
Shared::Outbox::Event.where(id:).where.not(dead_at: nil).update_all(dead_at: nil, attempts: 0, next_attempt_at: nil)
Shared::Outbox::PublishJob.new.perform   # ou espere a rotina, que roda a cada minuto
Shared::Outbox::Event.where(id:).pick(:published_at, :attempts, :dead_at)  # published_at preenchido = entregue
```

Se morrer de novo, a causa não foi corrigida: volte a inspecionar.

## Resolver de outra forma

Só quando a entrega não faz mais sentido e com a causa registrada, por exemplo um efeito que já foi aplicado à mão, depois de conferir o resultado no banco. Marque como publicado, sem apagar:

```ruby
Shared::Outbox::Event.where(id:).where.not(dead_at: nil).update_all(published_at: Time.current, dead_at: nil)
```

Não apague o evento: a rotina de limpeza o remove 30 dias depois de publicado.

## `consent.revoked` de `health_data` morto

Esse evento apaga as informações de saúde do perfil (consumidor `user_profile.erase_health_data`). Enquanto ele não for entregue, a pessoa **não consegue dar um novo consentimento de `health_data`**: `POST /api/v1/consents` responde `409 revocation_pending`. É proposital, para que o dado retirado não volte a valer sob um novo consentimento. Prioridade alta: reenfileire logo que a causa for corrigida. Só marque como resolvido à mão depois de conferir que esportes, motivações e nome de exibição daquela pessoa foram apagados.
