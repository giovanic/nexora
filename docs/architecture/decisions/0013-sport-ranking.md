# 0013 — Ranking por esporte

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-STRAVA-013, FR-GAME-010

## Contexto

O público inclui pessoas competitivas. O responsável imagina que cada pessoa veja a própria evolução, com uma aba de ranking por esporte, a aprofundar futuramente. O termo do Strava impede exibir dados de um usuário a outro ([fontes](../EXTERNAL_SOURCES.md)). Um ranking por volume premia excesso, o que contraria os princípios de gamificação. Mostrar dados de saúde a terceiros também muda a análise de privacidade.

## Problema

Vale ter um ranking e, se sim, baseado em quê?

## Alternativas

1. **Sem ranking:** simples, seguro. Pode não satisfazer quem gosta de competir.
2. **Ranking de XP, excluindo qualquer XP de origem Strava:** legal quanto ao Strava, mas favorece quem registra manualmente, e pode ser fraudado.
3. **Ranking por consistência em grupos opcionais de amigos:** menor exposição; a origem dos dados continua limitada.
4. **Ranking baseado em dados do Strava:** **proibido pelo termo**.
5. **Desafios de constância com contagem agregada e anônima:** sem expor pessoas.

## Decisão

**Em vigor:** nada de ranking nas nove fases. Sem tabelas, telas ou endpoints. O motor de gamificação não precisa antecipar nada.

**Pré-condições, se for retomado:**

- Não usar dados vindos do Strava, nem derivados que os revelem.
- Participação opcional, desativada por padrão, com consentimento próprio.
- Critérios que não premiem volume nem excesso.
- Reavaliação de privacidade e proteção contra fraude.
- Moderação e bloqueio, caso existam perfis visíveis.

**Quando retomar:** decisão do responsável, com dados do uso real. O caminho mais promissor a avaliar é a alternativa 3 ou a 5.

## Justificativa

Registrar agora evita que um agente implemente algo violando o termo, e preserva a ideia sem gastar tempo agora.

## Consequências

- Competição, por enquanto, é contra si mesmo.
- Se pedido, exigirá nova fase e nova ADR.

## Estado da decisão

Proposta
