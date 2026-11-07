# 0009 — Princípios de segurança da gamificação

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-GAME-008, FR-GAME-010, FR-GAME-007, NFR-SAFETY-002

## Contexto

Pontos e sequências mudam comportamento. Em um produto de alimentação e exercício, premiar a métrica errada pode reforçar restrição, excesso de treino e culpa. O Master Prompt proíbe premiar restrição alimentar, déficit calórico, excesso de exercício ou perda de peso. O responsável quer atender do iniciante ao competitivo.

## Problema

Como manter o jogo motivador, justo entre níveis, sem que nenhum caminho de pontuação recompense comportamento prejudicial?

## Alternativas

1. **XP proporcional a volume:** fácil de entender, atrai competitivos, mas premia excesso e é injusto com iniciantes.
2. **XP proporcional, com avisos:** mantém o incentivo errado.
3. **XP por cumprir o que faz sentido ao perfil, com tetos e sem dados de corpo ou calorias:** menos "emocionante" para quem compete por volume, mas justo e seguro.

## Decisão

Alternativa 3:

- Critérios proibidos estão listados em [GAMIFICATION_ARCHITECTURE.md](../GAMIFICATION_ARCHITECTURE.md), e são impostos em dados, regras e testes.
- Eventos para este contexto não carregam calorias, macronutrientes, peso ou distância.
- Sessão de atividade vale o mesmo, independentemente de duração ou distância, com teto diário e semanal.
- Recuperação planejada pontua e mantém a sequência.
- Sequências têm tolerância. Mensagens não usam medo de perder.
- Competição é contra si mesmo: recordes pessoais e comparação com períodos anteriores.

## Justificativa

Tornar impossível, por construção, é mais confiável do que revisar cada regra. A adaptação por nível resolve a justiça entre públicos.

## Consequências

- Pessoas muito competitivas podem achar o sistema pouco desafiador. Observar no uso e tratar pelas missões avançadas, sem afrouxar os critérios.
- Toda regra nova precisa passar pelo teste de critérios proibidos.
- Afrouxar estes princípios exige nova ADR aprovada pelo responsável.

## Estado da decisão

Aceita
