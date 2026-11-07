# 0011 — Sem meta de calorias

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-GOALS-005, NFR-SAFETY-001, NFR-SAFETY-004

## Contexto

O primeiro entregável, na visão do responsável, é medir calorias por foto e acompanhar metas diárias. O Master Prompt proíbe mecanismos de restrição alimentar e pontuação baseada em calorias. Muitos apps do gênero oferecem meta de calorias, o que pode afetar atração e monetização. Estimar por foto é incerto, o que torna um limite exato ainda menos defensável.

Em 2026-11-05, o responsável escolheu seguir sem meta e reavaliar depois com dados do beta.

## Problema

As metas diárias devem incluir uma meta ou um teto de calorias?

## Alternativas

1. **Sem meta, reavaliando com dados do beta:** calorias só como estimativa em faixa. Metas de hábito. Fiel ao Master Prompt. Risco: o produto pode atrair menos.
2. **Sem meta, como princípio permanente:** o mesmo produto, sem previsão de rever.
3. **Meta opcional protegida:** referência escolhida por adultos, sem XP, sem alerta de limite, com piso mínimo e bloqueio para perfis de risco. Exige flexibilizar o Master Prompt e mais trabalho de segurança.

## Decisão

**Em vigor por decisão do responsável:** alternativa 1. Não há meta nem teto de calorias. `goal_type` não aceita esses tipos, no banco e na API (FR-GOALS-005).

**Permanece em aberto:** se isso deve mudar. A reavaliação ocorre após o M1, com dados de uso e relatos, e **só o responsável** pode reabrir a questão. Até lá, nenhum agente implementa algo nessa direção.

**Como validar:** no beta, medir retenção e registrar pedidos espontâneos por meta de calorias. Se a reabertura ocorrer, a nova decisão precisa de avaliação de segurança, considerando riscos a pessoas com transtornos alimentares.

## Justificativa

É a leitura mais segura do Master Prompt, e a mais barata de manter. Adicionar depois é mais fácil do que retirar um recurso que reforça restrição.

## Consequências

- O registro de calorias funciona como informação, nunca como limite.
- Parte do público pode preferir concorrentes.
- As telas não exibem "calorias restantes" nem comparação com limite (NFR-SAFETY-004).

## Estado da decisão

Proposta
