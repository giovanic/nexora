# Arquitetura

Detalhes em `docs/architecture/SYSTEM_OVERVIEW.md` e `docs/architecture/DOMAIN_MODEL.md`.

- O sistema é um monólito modular em Rails, em monorepo. Não crie microsserviços nem Rails Engines por domínio sem ADR.
- Toda regra de negócio fica no backend. Web e mobile apresentam, e não calculam XP, nutrição ou conclusão de metas.
- Um domínio só fala com outro por `<Contexto>::Api` ou por eventos. Nunca leia ou grave tabelas de outro domínio, nem associe modelos de domínios diferentes.
- Nenhum domínio depende de Gamification, Notifications ou Progress & Analytics. Gamification só escuta eventos, e Progress & Analytics também pode ler APIs públicas.
- Eventos que não podem se perder passam pela outbox, na mesma transação da mudança. Consumidores são idempotentes.
- Integrações externas ficam atrás de adaptadores. Trocar de provedor de IA não pode alterar Nutrition.
- Mudança arquitetural importante exige ADR em `docs/architecture/decisions/` antes do código. ADR `Proposta` não é decisão final.
- Antes de usar uma API externa ou versão, confira `docs/architecture/EXTERNAL_SOURCES.md` e consulte de novo a fonte oficial.
