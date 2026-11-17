# Desenho da API

Contrato entre o backend e os clientes. As rotas de Identity & Access e de User Profile (Fase 02) e as de Nutrition, Food AI e do catálogo de alimentos (Fase 03) estão implementadas e seguem o contrato OpenAPI (`packages/contracts/openapi.yaml`), que é a fonte. O restante é o desenho inicial; cada fase confirma o seu trecho no contrato.

## Princípios

- **REST com JSON**, descrita em OpenAPI, que é a fonte dos tipos dos clientes. A versão atual da especificação é a 3.2.1 ([fontes](EXTERNAL_SOURCES.md)). Ferramentas e versão adotada são decididas na [ADR 0014](decisions/0014-api-contract-tooling.md). `rswag` não é adotado sem avaliação, pois declara compatibilidade com OpenAPI 3.0 e busca mantenedores.
- **Versionamento** no caminho: `/api/v1`. Mudança incompatível cria nova versão.
- **O backend decide regra de negócio.** A API devolve resultados prontos, como progresso, XP e faixas.
- **Controllers enxutos:** autenticar, autorizar, chamar um serviço, serializar.

## Autenticação e autorização

- Estratégia de sessão e tokens na [ADR 0005](decisions/0005-authentication-strategy.md) (`Aceita`). **Web:** cookie `__Host-session`, sem token no corpo; requisição que muda estado exige `Origin` permitido. **Mobile:** `Authorization: Bearer`, com o token no corpo da resposta de cadastro, entrada e renovação.
- **Campo `client`:** obrigatório (`web` ou `mobile`) em `POST /registrations` e `POST /sessions`, e escolhe o transporte da sessão. Valor desconhecido responde `422` com detalhe no campo `client`.
- Toda resposta leva `Cache-Control: no-store`.
- Toda rota, salvo cadastro, login, recuperação de senha, webhook, callback OAuth (validado pelo `state`) e saúde, exige autenticação.
- Exportação e exclusão de conta exigem a senha na própria requisição (reautenticação); senha errada responde `401 invalid_credentials`, sem encerrar a sessão. Porque uma sessão roubada não pode levar todo o histórico.
- **Isolamento:** consultas partem sempre do usuário autenticado, pela API do contexto, como `Nutrition::Api.find_entry(user_id: current_user.id, id:)`. Recurso de outra pessoa responde `404`, nunca `403`, para não confirmar a existência.
- Rotas que dependem de consentimento respondem `403` com o código `consent_required`. Sem `health_data`, só ficam liberadas sessão, consentimentos, exportação, exclusão e saída.

**Códigos de erro da Fase 02** (campo `error.code`):

| Status e código | Quando |
|---|---|
| `401 unauthorized` | Sessão ausente, inválida, revogada ou expirada; token de renovação já usado |
| `401 invalid_credentials` | E-mail ou senha errados na entrada, ou senha errada em exportação e exclusão. Não diz qual dos dois errou |
| `403 consent_required` | Rota que exige um consentimento que não está vigente |
| `403 forbidden` | `Origin` não permitido numa requisição com cookie que muda estado |
| `404 not_found` | Recurso inexistente ou de outra pessoa; finalidade desconhecida |
| `409 profile_pending` | Perfil ainda não criado a partir do cadastro (o app tenta de novo) |
| `409 revocation_pending` | Novo consentimento de `health_data` enquanto a revogação anterior ainda não foi aplicada |
| `409 outdated_version` | Consentimento concedido numa versão que não é a vigente |
| `422 validation_failed` | Campos inválidos, com `details`; inclui senha fraca na recuperação |
| `422 invalid_time_zone` | Fuso que não é IANA |
| `422 invalid_token` | Token de recuperação desconhecido, usado ou expirado |
| `429 too_many_requests` | Limite de tentativas excedido, com `Retry-After` em segundos |

## Formato de erro

Único em toda a API, tratado centralmente:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Mensagem para exibir ao usuário",
    "details": [{ "field": "target", "code": "unsupported_goal_type" }],
    "request_id": "01J..."
  }
}
```

| Status | Uso |
|---|---|
| 400 | Requisição malformada |
| 401 | Sem autenticação válida |
| 403 | Falta consentimento |
| 404 | Inexistente ou de outra pessoa |
| 409 | Conflito de estado |
| 422 | Falha de validação de negócio |
| 429 | Limite excedido, com `Retry-After` |
| 5xx | Erro interno, sem detalhes |

## Paginação, filtros e datas

- **Paginação por cursor** em todas as listagens: `?cursor=...&limit=50`, com limite máximo definido. A resposta traz `next_cursor`.
- **Filtros** explícitos: `?from=2026-11-01&to=2026-11-07&type=run`.
- **Datas:** instantes em ISO 8601 UTC. O "dia da pessoa" aparece em `local_date`.

## Idempotência

Rotas de criação que podem ser repetidas aceitam `Idempotency-Key` ou `client_request_id`. A mesma chave devolve o mesmo resultado, sem nova criação.

## Estimativas

Estimativa nunca aparece como número único:

```json
{
  "calories": { "min": 550, "likely": 650, "max": 750, "unit": "kcal", "is_estimate": true },
  "confidence": "medium",
  "sources": [{ "name": "USDA FoodData Central", "version": "2026-10" }]
}
```

Os valores acima são apenas ilustrativos.

## Recursos por contexto

### Identity & Access (Fase 02)

| Método e rota | Função |
|---|---|
| `POST /api/v1/registrations` | Criar conta, exigindo confirmação de maioridade, `time_zone` IANA e `client`. Cria a sessão |
| `POST /api/v1/sessions` | Entrar (`email`, `password`, `client`) |
| `GET /api/v1/sessions`, `DELETE /api/v1/sessions/:id`, `DELETE /api/v1/sessions/current` | Listar os dispositivos, revogar um deles, sair deste aparelho. Sessão de outra pessoa responde `404` |
| `POST /api/v1/sessions/refresh` | Renovar a sessão: troca o token. Duas renovações simultâneas com o mesmo token, só uma vence; a outra recebe `401` |
| `POST /api/v1/password_resets` | Pedir o link de recuperação de senha; responde sempre `202` |
| `PATCH /api/v1/password_resets/:token` | Trocar a senha com o token do link; encerra todas as sessões |
| `GET`/`POST /api/v1/consents`, `DELETE /api/v1/consents/:purpose` | Consultar, conceder, revogar. Versão diferente da vigente responde `409 outdated_version`; revogar `health_data` responde `204` como as outras finalidades, e as rotas de saúde passam a responder `403 consent_required` |
| `GET /api/v1/consents/:purpose/text` | Texto da versão vigente, em Markdown |
| `POST /api/v1/account/export` | Exportação gerada na hora, em JSON, com a senha; sem arquivo guardado |
| `DELETE /api/v1/account` | Solicitar exclusão, com a senha. Revoga todas as sessões na hora e apaga por contexto em até 24 horas |

### User Profile (Fase 02)

| Método e rota | Função |
|---|---|
| `GET`/`PATCH /api/v1/profile` | Perfil, motivações e fuso. Exige `health_data`; antes de o perfil nascer do cadastro responde `409 profile_pending`; fuso desconhecido responde `422 invalid_time_zone` |
| `GET`/`POST /api/v1/sport_profiles`, `DELETE /api/v1/sport_profiles/:id` | Esportes e níveis. Trocar o nível encerra a linha e abre outra, e o histórico fica. Exige `health_data` |

### Nutrition e Food AI (Fase 03)

Todas exigem `health_data` (`403 consent_required` sem ele). O contrato `packages/contracts/openapi.yaml` é a fonte; esta tabela só resume. Resposta de refeição nunca é guardada em cache, porque pode trazer a URL assinada da foto.

| Método e rota | Função | Respostas de erro |
|---|---|---|
| `POST /api/v1/food_entries/uploads` | Verificar o consentimento `food_photo_ai` e a quota, criar a refeição pendente e devolver a URL assinada de PUT. `201` na primeira vez; `200` ao repetir o mesmo `client_request_id` (sem URL, se a foto já passou do envio) | `403 consent_required`, `403 consent_operator_mismatch`, `422 unsupported_media_type`, `422 validation_failed` (com `details`), `409 upload_expired`, `429 analysis_quota_exceeded` |
| `POST /api/v1/food_entries/{id}/analysis` | Pedir a análise da foto já enviada; responde `202` e a refeição passa a `processing` | `404`, `409 entry_not_analyzable`, `409 analysis_retry_limit`, `422 not_uploaded`, `422 invalid_photo`, `403 consent_required`, `403 consent_operator_mismatch`, `429 analysis_quota_exceeded`, `429` por limite de requisições |
| `GET /api/v1/food_entries/{id}` | Estado e resultado: itens, faixas, confiança e, enquanto a foto existe, `photo_url` | `404` |
| `POST /api/v1/food_entries` | Registro manual, já confirmado, sem foto e sem quota | `422 validation_failed` |
| `POST /api/v1/food_entries/{id}/confirmation` | Confirmar a refeição analisada | `404`, `409 entry_not_confirmable` |
| `POST /api/v1/food_entries/{id}/items`, `PATCH`/`DELETE /api/v1/food_entries/{id}/items/{item_id}` | Acrescentar, corrigir porção ou alimento, e remover item; a refeição é recalculada | `404`, `409 entry_not_editable`, `422 validation_failed` |
| `GET /api/v1/food_entries?local_date=&cursor=&per_page=` | Histórico por cursor (`per_page` padrão 20, máximo 50). Nele `photo_url` é sempre nulo | `422 validation_failed` |
| `DELETE /api/v1/food_entries/{id}` | Apagar a refeição, os itens, a foto e as análises (`204`) | `404` |
| `POST /api/v1/foods/search` | Busca no catálogo, com o termo no corpo, para que o que a pessoa comeu não vá para logs de URL. `page` de 1 a 1000 | `422 validation_failed` |

**Códigos novos da Fase 03** (campo `error.code`):

| Status e código | Quando |
|---|---|
| `403 consent_required` | Falta `health_data` ou, no envio e na análise, `food_photo_ai` |
| `403 consent_operator_mismatch` | O consentimento `food_photo_ai` vigente não cobre o operador e a região em uso, ou é de uma versão anterior. Enquanto não existir a v2 do texto, todo envio real de foto responde isto |
| `429 analysis_quota_exceeded` | Quota diária de fotos esgotada; com `Retry-After` até o fim do dia da pessoa. Também no novo pedido de análise depois de uma falha, que conta de novo |
| `409 analysis_retry_limit` | A foto já recebeu 3 pedidos de análise. A refeição fica `failed`; o app oferece outra foto ou o registro manual |
| `409 upload_expired` | O mesmo `client_request_id` de um envio que foi descartado por abandono. Nenhuma refeição é criada, e o app recomeça com outro `client_request_id` |
| `422 unsupported_media_type` | Tipo fora de JPEG, PNG, WebP, HEIC e HEIF. Traz `details` com `content_type` |
| `422 not_uploaded` | O objeto da foto ainda não está no armazenamento |
| `422 invalid_photo` | O objeto no armazenamento não tem o tamanho nem o tipo autorizados (`details`: `photo` com `size_mismatch` ou `type_mismatch`). A recusa do conteúdo (tipo real pelos bytes, 40 megapixels, ilegível) acontece depois, no job, e a refeição vira `failed` |
| `409 entry_not_analyzable` | A refeição não está `pending` ou `failed` |
| `409 entry_not_confirmable` | A refeição não está analisada, ou não tem item |
| `409 entry_not_editable` | A refeição ainda não foi analisada |
| `429` (`too_many_requests`) | Mais de 10 pedidos de análise por minuto por pessoa, com `Retry-After: 60` |

### Goals (Fase 05)

| Método e rota | Função |
|---|---|
| `GET /api/v1/goal_types` | Tipos permitidos |
| `GET`/`POST`/`PATCH`/`DELETE /api/v1/goals` | Metas |
| `POST /api/v1/goals/:id/check_ins` | Check-in manual |
| `GET /api/v1/goals/history` | Histórico |
| `GET`/`PUT /api/v1/weekly_plans/:week_start` | Planejamento (etapa 05.2) |

### Activities e Strava (Fase 04)

| Método e rota | Função |
|---|---|
| `GET`/`POST`/`PATCH`/`DELETE /api/v1/activities` | Histórico e registro manual |
| `POST /api/v1/integrations/strava/authorization` | Iniciar OAuth |
| `GET /api/v1/integrations/strava/callback` | Concluir OAuth |
| `GET /api/v1/integrations/strava` | Estado da integração e sincronização |
| `DELETE /api/v1/integrations/strava` | Desconectar e apagar |
| `GET`/`POST /webhooks/strava` | Validação e eventos ([detalhes](STRAVA_INTEGRATION.md)) |

### Gamification e Missions (Fase 06)

| Método e rota | Função |
|---|---|
| `GET /api/v1/progression` | XP, nível, sequências |
| `GET /api/v1/xp_transactions` | Histórico, com motivo |
| `GET /api/v1/missions` | Missões da pessoa |
| `GET /api/v1/achievements` | Conquistas |

Não existe rota para o cliente conceder XP ou concluir missão.

### Notifications e Progress (Fase 08)

| Método e rota | Função |
|---|---|
| `GET`/`PATCH /api/v1/notifications` | Caixa de mensagens |
| `POST /api/v1/device_tokens` | Registrar aparelho para push |
| `GET /api/v1/progress/summary` | Evolução |
| `GET /api/v1/reports/weekly/:week_start` | Relatório semanal |

### Operação (Fase 01)

| Rota | Função |
|---|---|
| `GET /health/live` | Processo vivo |
| `GET /health/ready` | Banco e Redis acessíveis |

O calendário das Fases 07 e 08 é composto pelos clientes a partir de refeições, metas e atividades, com filtros por período. Um endpoint próprio só existirá com medição que o justifique.

## Uploads

1. O app chama `POST /food_entries/uploads`. O backend verifica consentimento e limite de análises.
2. A resposta traz uma URL assinada de prazo curto, restrita a tipo e tamanho.
3. O app envia a foto direto ao armazenamento privado.
4. O app pede a análise (`POST /food_entries/{id}/analysis`). O backend confere que o objeto foi enviado e enfileira o job; é o job que verifica o tipo e o tamanho reais do objeto e remove o EXIF, substituindo o objeto, antes de chamar a IA.

O servidor nunca recebe a foto pela API, o que reduz custo e superfície de ataque. Tipos e tamanho máximo levam em conta os limites dos provedores ([fontes](EXTERNAL_SOURCES.md)).

## Limites de uso

Limite de tentativas em autenticação, de requisições por usuário e de análises por período. Na Fase 02: cadastro, entrada, renovação, recuperação de senha, exportação e exclusão têm limite por IP; cadastro, entrada e recuperação, também por e-mail; exportação e exclusão, também por conta (valores e trade-offs em [SECURITY.md](../security/SECURITY.md)). Excedido, responde `429` com `Retry-After` e, no caso de análises, com o código `analysis_quota_exceeded`. Na Fase 03, o pedido de análise tem ainda o limite de 10 por minuto por pessoa e o de 3 pedidos por foto (`analysis_retry_limit`).

## Compatibilidade entre clientes

O app móvel não atualiza junto com o servidor. Campos novos são adicionais, remoções passam por uma nova versão, e o contrato OpenAPI é verificado no CI contra a implementação.
