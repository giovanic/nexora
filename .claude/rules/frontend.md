---
paths:
  - "apps/web/**"
  - "packages/**"
---

# Painel web (React e TypeScript)

Detalhes em `docs/engineering/CODING_STANDARDS.md`.

- TypeScript estrito, sem `any` sem justificativa.
- Tipos da API vêm do contrato OpenAPI, nunca escritos à mão.
- Sem regra de negócio no cliente.
- Componentize, e separe estado de apresentação.
- Toda tela trata carregando, vazio e erro, com testes.
- Formulários validados, com mensagem acessível. A validação definitiva é do backend.
- Acessibilidade: teclado, foco, contraste e rótulos, buscando WCAG 2.2 AA.
- Credenciais em cookie `HttpOnly`, nunca em `localStorage`.
- Variável `VITE_` vai para o navegador: nunca coloque segredo nela.
- Estimativas sempre em faixa. Sem cor de alerta ou comparação com limite para calorias.
- Textos seguem a lista de linguagem de `docs/security/HEALTH_DATA_SAFETY.md`.
