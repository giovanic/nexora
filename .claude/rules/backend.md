---
paths:
  - "apps/api/**"
---

# Backend (Ruby e Rails)

Detalhes em `docs/engineering/CODING_STANDARDS.md`.

- Controllers enxutos: autenticam, autorizam, chamam um serviço e serializam.
- Services têm uma responsabilidade e nome de verbo, como `ConfirmFoodEntry`.
- Domínio separado de infraestrutura: clientes HTTP ficam em `adapters/`.
- Aplique SOLID quando ajudar, DRY sobre conhecimento e YAGNI sempre.
- Consultas de dados de usuário sempre partem do usuário autenticado. Recurso de outra pessoa responde `404`.
- Transação em toda escrita atômica, incluindo a outbox. Nunca faça chamada externa dentro de transação.
- Jobs recebem identificadores e são idempotentes.
- Erros são tratados de forma central, no formato de `docs/architecture/API_DESIGN.md`.
- Sem callback de modelo com efeito externo.
- Testes em RSpec, lint em RuboCop, segurança com Brakeman e auditoria de dependências.
- Toda estimativa usa faixa (`_min`, `_likely`, `_max`), com confiança.
- Filtre dados sensíveis de logs: tokens, URLs assinadas, itens de refeição, valores nutricionais e e-mails.
