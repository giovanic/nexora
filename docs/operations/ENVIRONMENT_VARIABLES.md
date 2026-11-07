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
| `DATABASE_URL` | 01 | Sim | PostgreSQL. Obrigatória em produção |
| `REDIS_URL` | 01 | Sim em produção | Valkey para o Sidekiq. O nome é o que o Sidekiq lê. Obrigatória em produção |
| `SECRET_KEY_BASE` | 01 | Sim | Base criptográfica do Rails. Obrigatória em produção. Sem credenciais do Rails, portanto sem `RAILS_MASTER_KEY` |
| `ALLOWED_ORIGINS` | 01 | Não | Origens do painel web, separadas por vírgula. `*` é descartado. Obrigatória em produção |
| `ERROR_TRACKING_DSN` | 01 | Sim | Monitoramento de erros. Sem ela, fica inativo |
| `LOG_LEVEL` | 01 | Não | Nível de log. Padrão `info`. Produção não aceita `debug` |
| `ENCRYPTION_PRIMARY_KEY` e afins | 02 | Sim | Cifragem em nível de aplicação; nomes conforme a ferramenta |
| `MAIL_*` | 02 | Sim | Serviço de e-mail |
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

Os DSNs públicos de monitoramento não são segredos, mas devem ter o envio de dados sensíveis desativado.
