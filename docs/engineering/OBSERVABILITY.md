# Observabilidade

O desenvolvedor é único, então os sinais precisam apontar o problema sem exigir plantão ou investigação longa. A base veio da Fase 01: `lograge` e formatador JSON próprio nos logs, e Sentry nos erros. Cada fase amplia o que precisar.

## Regra central

**Dados sensíveis não entram em logs, métricas ou relatórios de erro** (NFR-PRIVACY-004). Isso inclui fotos, URLs assinadas, nomes de alimentos, valores nutricionais, atividades, tokens, senhas e e-mails. Use identificadores.

Filtros de parâmetros e de erro ficam configurados em todas as aplicações. Um teste verifica logs de um fluxo completo.

## Logs

- **Estruturados** em JSON.
- **Campos:** `timestamp`, `level`, `message`, `request_id`, `correlation_id`, `user_ref`, `context`, `duration_ms`. `user_ref` entra com a autenticação, na Fase 02.
- **Correlação:** `correlation_id` atravessa requisição e job, e chega ao evento com a outbox (NFR-OBS-001). Vem do cabeçalho `X-Correlation-Id` quando válido, ou é gerado, e volta na resposta. O cliente pode escolhê-lo, então ele não serve como prova de origem.
- **Exceções:** logs guardam só a classe. A mensagem pode trazer dados de usuário. Por isso, produção nunca usa o nível `debug`, mesmo com `LOG_LEVEL=debug`.
- **Retenção:** definida no M1, junto com a hospedagem, porque hoje não há logs de produção.

## Erros

O Sentry recebe erros de backend, jobs, web e mobile (NFR-OBS-002), somente com DSN configurado. Ele é avaliado como operador na [política de privacidade](../security/PRIVACY_AND_LGPD.md), com retenção de 30 dias no plano gratuito.

Cada aplicação tem um filtro antes do envio, que mantém o tipo e a pilha, e remove mensagem, usuário, parâmetros, cabeçalhos, cookies e campos desconhecidos.

**Limite no mobile:** o SDK nativo envia relatórios de crash sem passar pelo filtro, então a captura de crash nativo fica desligada. Reavaliar com a filtragem nativa quando houver build de distribuição, no M1.

## Saúde

| Rota | Verifica | Uso |
|---|---|---|
| `/health/live` | Processo responde | Reinício do processo |
| `/health/ready` | PostgreSQL e Valkey, com prazo de 2 segundos | Deploy e balanceador |

A verificação própria do Sidekiq entra no M1, com o deploy.

## Métricas e alertas

| Sinal | Métrica | Alerta inicial | A partir de |
|---|---|---|---|
| API | Taxa de erro 5xx, p95 | Erro acima do normal | M1 |
| Filas | Tamanho e tempo de espera por fila | Espera acima de um limite | M1 |
| Jobs mortos | Contagem | Qualquer novo em fila crítica | M1 |
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
