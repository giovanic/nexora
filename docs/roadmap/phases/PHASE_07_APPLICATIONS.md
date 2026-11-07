# Fase 07 — Mobile & Web Experience

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** FR-WEB-001, FR-WEB-002, FR-WEB-003, FR-WEB-004, FR-MOBILE-004, NFR-A11Y-001, NFR-A11Y-002, NFR-PERF-001

## Objetivo

Consolidar a experiência: os principais fluxos funcionam de ponta a ponta no mobile e na web, com consistência visual e acessibilidade.

## Escopo

**Inclui:** painel web completo; consolidação do app; identidade visual; navegação; gráficos; calendário; responsividade; acessibilidade; verificação de textos.

**Não inclui:** notificações, relatórios semanais e insights (Fase 08), nem novas regras de negócio. Toda regra continua no backend.

## Funcionalidades

- **Sistema visual** compartilhado em conceitos: cores, tipografia, espaçamento, estados, tom de voz. O compartilhamento de código entre web e mobile é avaliado, sem assumir.
- **Painel web:** visão geral, calendário, histórico alimentar, histórico de atividades, XP, nível, sequências, metas, missões, conquistas e configurações, incluindo privacidade.
- **Mobile:** navegação final, painel, XP, nível, sequências, missões e conquistas.
- **Gráficos** de constância e evolução, sem cores de alerta para calorias, nem comparação com limite.
- **Calendário** por `local_date`.
- **Direção visual:** propostas apresentadas ao responsável antes da implementação, com `superpowers:brainstorming`. O produto deve ser visualmente interessante, intuitivo e distinto.

## Dependências

- **Fases 03, 04, 05.2 e 06** concluídas.
- **Fontes a consultar:** WCAG e bibliotecas de gráficos.

## Arquivos e módulos esperados

```text
apps/web/src/features/        dashboard, calendar, meals, activities, progression, goals, missions, achievements, settings
apps/mobile/src/features/     dashboard, progression
```

## Critérios de aceite

- `AC-07-01` (FR-WEB-001, FR-WEB-002): visão geral, calendário e históricos mostram os mesmos dados do mobile para a mesma conta. **Comprovado por:** teste end-to-end e demonstração.
- `AC-07-02` (FR-WEB-003): XP, nível, sequências, metas, missões e conquistas funcionam na web. **Comprovado por:** teste end-to-end.
- `AC-07-03` (FR-WEB-004): configurações na web incluem privacidade, exportação e exclusão de conta. **Comprovado por:** teste end-to-end com a conta sendo realmente excluída.
- `AC-07-04` (FR-MOBILE-004): XP, nível, sequências, missões e conquistas funcionam no app. **Comprovado por:** teste de fluxo e demonstração.
- `AC-07-05`: o calendário é composto pelos clientes a partir dos dados existentes, por `local_date`, sem regra de negócio no cliente. **Comprovado por:** testes com fusos diferentes e revisão pelo `frontend-mobile-reviewer`.
- `AC-07-06` (NFR-A11Y-001): os fluxos principais da web passam em ferramenta automática e em revisão manual de teclado e leitor de tela segundo WCAG 2.2 AA. **Comprovado por:** relatório.
- `AC-07-07` (NFR-A11Y-002): os fluxos principais do app funcionam com leitor de tela. **Comprovado por:** roteiro executado em aparelho real.
- `AC-07-08` (NFR-PERF-001): endpoints de leitura usados pelos painéis têm p95 de até 300 ms com volume de teste definido no plano. **Comprovado por:** medição registrada.
- `AC-07-09`: todas as telas têm estados de carregando, vazio e erro, e ficam utilizáveis nas larguras definidas no plano. **Comprovado por:** testes de componente e capturas de tela.
- `AC-07-10`: textos estáticos das aplicações passam pela lista de linguagem, e gráficos não usam alerta para calorias. **Comprovado por:** verificação automática e revisão.

## Testes

End-to-end nos fluxos principais, nas duas plataformas (ferramenta escolhida no plano). Testes de componente. Acessibilidade automática. Regressão visual somente se justificada.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Duplicar lógica nos clientes | Divergência | Regra no backend, revisão |
| Consumo de tempo com polimento | Atraso | Priorizar fluxos principais; escopo do plano |
| Marca indefinida | Retrabalho visual | Tokens de design, fáceis de trocar |

## Entregáveis

Painel web, app consolidado, sistema visual documentado, relatórios de acessibilidade e relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais: demonstração dos fluxos principais nas duas plataformas.

## Estratégia de revisão

`frontend-mobile-reviewer` (principal), `software-architect` (regra só no backend), `backend-reviewer` (consultas), `security-reviewer` (credenciais, textos), `qa-reviewer` (end-to-end). O responsável aprova a direção visual antes da implementação, e o relatório no fim.
