---
paths:
  - "apps/api/**"
---

# Banco de dados

Desenho em `docs/architecture/DATABASE_DESIGN.md`.

- A regra vale no banco: `NOT NULL`, `CHECK`, `UNIQUE` e chaves estrangeiras, não só validação de modelo.
- Cada índice precisa de uma consulta real que o justifique.
- Migrations reversíveis quando possível. Se não for possível, explique no arquivo.
- Evite N+1 e consultas desnecessárias. Antes de otimizar, conte as consultas com N e com 3N.
- Listagens sempre paginadas, com limite máximo.
- Proteja a concorrência com índice único como última defesa, e bloqueio onde houver disputa.
- Idempotência no banco: `xp_transactions`, `consumed_events`, `activity_sync_events` e `activities` têm índices únicos que não podem ser removidos.
- `goals.goal_type` é lista fechada, e não aceita calorias, déficit, peso ou compensação.
- Toda nova tabela com dados de usuário entra na exclusão de conta, na exportação e na retenção.
- Dados de saúde são apagados de verdade. Soft delete só onde o desenho indicar.
