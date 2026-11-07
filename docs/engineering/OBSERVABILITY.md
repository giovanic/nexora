# Observabilidade

O desenvolvedor é único, então os sinais precisam apontar o problema sem exigir plantão ou investigação longa. Implementação inicial na Fase 01, com ampliação em cada fase. As ferramentas são escolhidas na Fase 01.

## Regra central

**Dados sensíveis não entram em logs, métricas ou relatórios de erro** (NFR-PRIVACY-004). Isso inclui fotos, URLs assinadas, nomes de alimentos, valores nutricionais, atividades, tokens, senhas e e-mails. Use identificadores.

Filtros de parâmetros e de erro ficam configurados em todas as aplicações. Um teste verifica logs de um fluxo completo.

## Logs

- **Estruturados** em JSON.
- **Campos:** `timestamp`, `level`, `message`, `request_id`, `correlation_id`, `user_ref`, `context`, `duration_ms`.
- **Correlação:** `correlation_id` atravessa requisição, job e evento (NFR-OBS-001).
- **Retenção curta,** definida na Fase 01.

## Erros

Uma ferramenta de monitoramento recebe erros de backend, jobs, web e mobile (NFR-OBS-002). Exigências: filtro de dados sensíveis e agrupamento. Ela é avaliada como operador na [política de privacidade](../security/PRIVACY_AND_LGPD.md).

## Saúde

| Rota | Verifica | Uso |
|---|---|---|
| `/health/live` | Processo responde | Reinício do processo |
| `/health/ready` | PostgreSQL e Redis | Deploy e balanceador |

Sidekiq também tem verificação própria, confirmada na Fase 01.

## Métricas e alertas

| Sinal | Métrica | Alerta inicial | A partir de |
|---|---|---|---|
| API | Taxa de erro 5xx, p95 | Erro acima do normal | Fase 01 |
| Filas | Tamanho e tempo de espera por fila | Espera acima de um limite | Fase 01 |
| Jobs mortos | Contagem | Qualquer novo em fila crítica | Fase 01 |
| Outbox | Pendentes mais antigos; mortos | Atraso acima de 5 minutos; qualquer morto | Primeira fase que usar a outbox |
| Food AI | Duração, taxa de falha, schema inválido | Falha acima de um limite | Fase 03 |
| **Custo de IA** | Custo por dia e por usuário | **Gasto acima do valor configurado** | Fase 03 |
| Webhook do Strava | Recebidos, atraso, erros | Sem eventos há tempo incomum; atraso alto | Fase 04 |
| Limites do Strava | Uso das janelas, 429 | Uso alto; qualquer 429 frequente | Fase 04 |
| Reconciliação | Divergências encontradas | Número alto | Fase 04 |
| XP | Divergência entre o livro-razão e o nível | Qualquer divergência | Fase 06 |
| Backups | Última execução e última restauração testada | Sem backup recente | M1 |

Os limites numéricos são definidos com base em dados reais. Poucos alertas, todos acionáveis: se um alerta não exige ação, ele é removido.

## Métricas de produto

Ativação e retenção conforme o [PRD](../product/PRD.md), somente com o consentimento `usage_metrics`. Ficam separadas da observabilidade técnica e com o mínimo de dados.

## Como agir

Cada alerta do M1 aponta para um procedimento curto em [RELEASE_CHECKLIST.md](../operations/RELEASE_CHECKLIST.md) ou em documento operacional da fase.
