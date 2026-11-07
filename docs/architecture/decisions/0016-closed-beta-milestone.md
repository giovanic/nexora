# 0016 — Marco de beta fechado

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-OPS-005, NFR-HARNESS-003

## Contexto

O responsável, que trabalha sozinho, define sucesso como ver pessoas usando o produto. O roadmap original prepara o beta apenas na Fase 09. Isso significaria construir nove fases sem nenhum retorno de uso real. O Strava limita apps novos a 1 atleta, ou 10 com upgrade, e acima disso exige revisão, o que também torna arriscado depender dele no primeiro beta.

## Problema

Como colocar o produto nas mãos de pessoas reais mais cedo, sem pular a privacidade nem desorganizar as fases?

## Alternativas

1. **Manter o beta só na Fase 09:** caminho original, com o maior risco de construir o produto errado.
2. **Reordenar e renumerar as fases:** antecipa, mas gera confusão com o documento original.
3. **Marco M1 sem mudar a numeração:** fases iguais, com um marco no meio e a Fase 05 dividida em etapas.

## Decisão

Alternativa 3. O marco **M1 — Beta fechado** coloca foto com estimativa e metas diárias de hábito nas mãos de até 10 pessoas. Conteúdo: Fases 01, 02 e 03 concluídas, a etapa `05.1`, com as telas mínimas e o [documento do marco](../../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md).

Ordem sugerida: 01 → 02 → 03 → 05.1 → M1 → 04 → 05.2 → 06 → 07 → 08 → 09.

Cada avanço continua dependendo da autorização do responsável.

## Justificativa

Aprender com uso real é o que mais reduz risco, tanto de produto quanto de monetização. Strava e gamificação podem esperar, porque o primeiro entregável não depende deles.

## Consequências

- Parte da preparação operacional (hospedagem, backups) ocorre antes.
- A Fase 09 reavalia esses itens na escala do lançamento, sem refazê-los.
- `STATUS.md` tem linhas para `05.1`, `05.2` e `M1`.
- O relato do beta pode reordenar as fases seguintes, com nova decisão do responsável.

## Estado da decisão

Aceita
