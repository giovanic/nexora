# 0006 — Pipeline de Food AI e abstração de provedor

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-FOOD-003, FR-FOOD-013, FR-FOOD-014, FR-FOOD-015, NFR-COST-001, NFR-PRIVACY-005

## Contexto

Fotos não permitem medir peso nem ver ingredientes escondidos. O mercado de modelos muda depressa, com preços e políticas diferentes ([fontes](../EXTERNAL_SOURCES.md)). O Master Prompt exige que seja possível trocar de provedor sem reescrever Nutrition. A pergunta do provedor concreto só pode ser respondida com medição.

## Problema

Como estruturar a análise para que a escolha de modelo não contamine o domínio, e como escolher o provedor?

## Alternativas

**Forma:**

1. **Um único prompt devolve tudo, incluindo calorias:** simples, mas os números ficam sem origem e impossíveis de auditar.
2. **Pipeline separando visão e cálculo:** o modelo identifica e estima porções; nosso código calcula a partir de bases com proveniência.
3. **Modelo próprio treinado:** controle total, com custo e dados fora de alcance.

**Provedor (situação de 2026-11-05):**

- Anthropic: preços verificados; política de dados verificada em parte.
- Google Gemini: preços verificados; nível gratuito proibido por usar conteúdo.
- OpenAI: preços e política de dados não verificados.

## Decisão

**Já vale:** alternativa 2, com interface `FoodAi::ProviderAdapter`, prompts versionados, saída com schema validado na aplicação, registro de custo e histórico, conforme [AI_ARCHITECTURE.md](../AI_ARCHITECTURE.md). Só provedores com política documentada de não treinar com as entradas.

**Fica para a Fase 03:** o provedor e o modelo, comparando ao menos dois candidatos com o dataset de avaliação quanto a qualidade, custo e latência, além da política de dados e da base legal de transferência.

## Justificativa

Separar visão e cálculo dá proveniência, permite testar cada parte, e torna a troca de provedor local. Escolher antes de medir seria uma decisão hipotética.

## Consequências

- Mais etapas e mais código do que um único prompt.
- A qualidade da estimativa depende também do catálogo.
- Trocar de modelo exige rodar a avaliação.

## Estado da decisão

Proposta
