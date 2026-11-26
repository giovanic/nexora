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

**Acréscimo de 2026-11-25** (decisão do responsável: "sim pode reabrir e implementar", com a condição de ser grátis):

- Groq, plano gratuito, modelo `qwen/qwen3.8-27b`: contrato proíbe treinar com entradas e saídas, sem exceção para o plano gratuito; aceita imagem e JSON Schema estrito. Riscos registrados: o modelo está em **prévia**, que a Groq diz servir só para avaliação e poder sair do ar com pouco aviso; limites baixos de uso; sem região fora dos EUA. O `openai/gpt-oss-120b`, pedido primeiro, só lê texto e não serve para foto ([fontes](../EXTERNAL_SOURCES.md), linhas da Groq).

## Decisão

**Já vale:** alternativa 2, com interface `FoodAi::Adapters::ProviderAdapter`, prompts versionados, saída com schema validado na aplicação, registro de custo e histórico, conforme [AI_ARCHITECTURE.md](../AI_ARCHITECTURE.md). Só provedores com política documentada de não treinar com as entradas.

**Fica para a Fase 07** (decisão do responsável de 2026-11-14 e 2026-11-16, que antes estava prevista para a Fase 03): o provedor e o modelo, comparando ao menos dois candidatos com o dataset de avaliação quanto a qualidade, custo e latência, além da política de dados e da base legal de transferência. As chaves de Anthropic, Gemini e OpenAI, e a rodada real de avaliação, também ficam para a Fase 07. A Fase 03 entregou os três adaptadores só testados com dublê, o dataset e a ferramenta de avaliação (`evaluation/` na raiz do repositório, com specs em `apps/api/spec/evaluation/`), sem rodada real.

**Reabertura de 2026-11-25:** a Fase 03 ganhou o quarto adaptador, `groq`, testado com dublê, e a avaliação aceita `PACE` para respeitar os limites do plano gratuito. Com a chave da Groq, fornecida pelo responsável, o adaptador rodou contra o provedor em 2026-11-25, só com fotos públicas do dataset: uma chamada de teste (`food_ai:smoke`) e a rodada `groq-r1` (ver `evaluation/reports/`). É o primeiro e, por enquanto, único adaptador com chamada real. Ela mede um candidato, mas não decide o provedor de produção: um modelo em prévia não atende o beta, e a comparação com ao menos dois candidatos continua exigida.

**Dependência do M1:** o [M1](../../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md) (beta com foto) vem antes da Fase 07 pelo roadmap e pela [ADR 0016](0016-closed-beta-milestone.md), mas depende desta ADR aceita e da rodada real. A ordem entre eles é decisão do responsável e continua em aberto. Sem provedor, todo envio real de foto é recusado (`consent_operator_mismatch`, consentimento `food_photo_ai` na v1 sem operador).

## Justificativa

Separar visão e cálculo dá proveniência, permite testar cada parte, e torna a troca de provedor local. Escolher antes de medir seria uma decisão hipotética.

## Consequências

- Mais etapas e mais código do que um único prompt.
- A qualidade da estimativa depende também do catálogo.
- Trocar de modelo exige rodar a avaliação.

## Estado da decisão

Proposta
