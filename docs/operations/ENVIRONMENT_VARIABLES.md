# Variáveis de ambiente

Lista sem valores. As da Fase 01 estão em uso; as demais são planejadas, e cada fase confirma as suas. Os nomes finais vão para `.env.example`, sem valores reais. No desenvolvimento, as variáveis da API são opcionais, porque os padrões batem com o `docker-compose.yml`.

## Regras

- Segredos nunca entram no repositório nem em logs.
- `.env` é ignorado pelo Git.
- Variáveis com prefixo `VITE_` ou `EXPO_PUBLIC_` vão para o cliente: **nunca coloque segredo nelas**.
- Em produção, os valores ficam no gerenciador da plataforma.
- A aplicação falha ao iniciar quando falta uma variável obrigatória, com mensagem clara.

## Backend

| Variável | Fase | Segredo | Finalidade |
|---|---|---|---|
| `SIDEKIQ_CONCURRENCY` | 01 | Não | Threads do Sidekiq; também dimensiona o pool do banco, padrão 5 |
| `DATABASE_URL` | 01 | Sim | PostgreSQL. Obrigatória em produção |
| `REDIS_URL` | 01 | Sim em produção | Valkey para o Sidekiq e para o `Rails.cache` (`:redis_cache_store`, namespace `cache`; em teste o cache é em memória). O nome é o que o Sidekiq lê. Obrigatória em produção |
| `SECRET_KEY_BASE` | 01 | Sim | Base criptográfica do Rails. Obrigatória em produção. Sem credenciais do Rails, portanto sem `RAILS_MASTER_KEY` |
| `ALLOWED_ORIGINS` | 01 | Não | Origens do painel web, separadas por vírgula. `*` é descartado. Obrigatória em produção |
| `ERROR_TRACKING_DSN` | 01 | Sim | Monitoramento de erros. Sem ela, fica inativo |
| `LOG_LEVEL` | 01 | Não | Nível de log. Padrão `info`. Produção não aceita `debug` |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | 02 | Sim | Chave primária do Active Record Encryption (tokens e dados cifrados em nível de aplicação). Obrigatória em produção. Em desenvolvimento e teste há um valor fixo e público, sem valor de segurança. Em produção, mínimo de 32 caracteres, ou o boot falha |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | 02 | Sim | Chave da cifragem determinística (consulta por igualdade). Obrigatória em produção; mesmo tratamento em desenvolvimento e teste. Em produção, mínimo de 32 caracteres, ou o boot falha |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | 02 | Sim | Sal da derivação de chaves do Active Record Encryption. Obrigatória em produção; mesmo tratamento em desenvolvimento e teste. Em produção, mínimo de 32 caracteres, ou o boot falha |
| `AUDIT_IP_HMAC_KEY` | 02 | Sim | Chave do HMAC que pseudonimiza o IP nos eventos de auditoria. Obrigatória em produção; em desenvolvimento e teste há um valor fixo e público. Em produção, mínimo de 32 caracteres, ou o boot falha |
| `APP_WEB_URL` | 02 | Sim | URL base do painel web, para links de e-mail. Obrigatória em produção, e deve ser `https://` sem barra final nem caminho, ou o boot falha; padrão `http://localhost:5173` em desenvolvimento e teste |
| `MAIL_FROM` | 02 | Não | Remetente dos e-mails da conta, como o link de recuperação de senha. Padrão `no-reply@localhost`. Em desenvolvimento os e-mails vão para arquivos em `apps/api/tmp/mails`, e em teste ficam em memória |
| `MAIL_*` (demais) | M1 | Sim | Credenciais do provedor de e-mail, escolhido no M1 |
| `STORAGE_BUCKET`, `STORAGE_REGION`, `STORAGE_ENDPOINT` | 03 | Não | Armazenamento privado |
| `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY` | 03 | Sim | Credenciais do armazenamento |
| `SIGNED_URL_TTL_SECONDS` | 03 | Não | No máximo 900 |
| `AI_PROVIDER`, `AI_MODEL` | 03 | Não | Provedor e modelo ativos |
| `AI_PROVIDER_API_KEY` | 03 | Sim | Credencial do provedor |
| `AI_ANALYSES_PER_DAY_LIMIT` | 03 | Não | Limite por usuário |
| `AI_DAILY_SPEND_ALERT_USD` | 03 | Não | Alerta de gasto total |
| `USDA_FDC_API_KEY` | 03 | Sim | API do FoodData Central, se usada |
| `STRAVA_CLIENT_ID` | 04 | Não | Aplicação do Strava |
| `STRAVA_CLIENT_SECRET` | 04 | Sim | Só no backend |
| `STRAVA_WEBHOOK_VERIFY_TOKEN` | 04 | Sim | Validação do webhook |
| `STRAVA_REDIRECT_URI` | 04 | Não | Callback OAuth |
| `PUSH_*` | 08 | Sim | Serviço de push |

## Painel web

| Variável | Fase | Finalidade |
|---|---|---|
| `VITE_API_URL` | 01 | URL da API |
| `VITE_ERROR_TRACKING_DSN` | 01 | Monitoramento de erros |

## Aplicativo móvel

| Variável | Fase | Finalidade |
|---|---|---|
| `EXPO_PUBLIC_API_URL` | 01 | URL da API |
| `EXPO_PUBLIC_ERROR_TRACKING_DSN` | 01 | Monitoramento de erros |
| `EXPO_PUBLIC_APP_WEB_URL` | 02 | URL do painel web, opcional, para o link "exportar pelo site" nas Configurações. Sem ela, o app mostra só o texto |

Os DSNs públicos de monitoramento não são segredos, mas devem ter o envio de dados sensíveis desativado.
