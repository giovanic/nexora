# Arquitetura de Food AI

Como uma foto vira uma estimativa nutricional honesta. Implementação na [Fase 03](../roadmap/phases/PHASE_03_FOOD_AI.md). Decisões: [ADR 0006](decisions/0006-food-ai-pipeline-and-provider-abstraction.md) e [ADR 0007](decisions/0007-nutrition-data-sources.md). Fatos externos: [fontes](EXTERNAL_SOURCES.md).

## Princípios

1. **Separar ver de calcular.** O modelo identifica alimentos e estima porções. Quem calcula nutrientes é o nosso código, com dados de uma base de origem conhecida. O modelo nunca é a fonte das calorias.
2. **Estimativa é faixa.** Toda grandeza tem mínimo, provável e máximo, além de confiança.
3. **Provedor substituível.** Trocar de provedor exige um adaptador e configuração, sem mexer em Nutrition.
4. **Tudo reprodutível.** Cada análise registra prompt, modelo, schema, resposta validada e custo.
5. **Falhar com honestidade.** Sem comida na foto, baixa confiança ou erro do provedor nunca viram um número inventado.

## Pipeline

```text
Câmera do app
    |  1. pede autorização (consentimento, limite de análises)
    v
Autorização de envio no backend
    |  2. URL assinada de prazo curto
    v
Armazenamento privado
    |  3. a pessoa pede a análise; a API confere que o objeto foi enviado
    v
Job em segundo plano (Sidekiq)
    |  4. valida o objeto real (tipo pelos bytes, tamanho) e normaliza a imagem:
    |     orientação, remoção de EXIF e de todos os metadados, HEIC/HEIF para JPEG
    v
Provedor de IA (por adaptador)
    |  5. resposta estruturada
    v
Validação de schema e de limites
    |  6. lista de itens com faixa de porção e confiança
    v
Identificação e porções
    |  7. food_analysis.completed: Food AI termina aqui; Nutrition assume
    |     e faz a correspondência com o catálogo
    v
Adaptador de base nutricional
    |  8. nutrientes por 100 g, com origem e versão
    v
Calculadora nutricional
    |  9. faixas por item e da refeição
    v
Confiança e incerteza
    |  10. resultado salvo na refeição
    v
Refeição aguardando confirmação
```

O passo 4 acontece **no job, antes da IA** (`FoodAi::NormalizePhoto`, chamado por `RunAnalysis#prepare`): remove o EXIF e os demais metadados e **substitui o objeto guardado** pela cópia normalizada, para que localização e dados do aparelho não fiquem no armazenamento nem cheguem ao provedor. Aceita JPEG, PNG, WebP, **HEIC e HEIF** (convertidos para JPEG, decisão do responsável de 2026-11-14; o tipo real é lido dos bytes e deve bater com o declarado). O processamento limita o tamanho a 10 MB e a imagem a 40 megapixels antes de decodificar (contra bombas de descompressão) e reduz o lado maior a 1.568 px. Foto sem comida ou ilegível tem o objeto apagado.

## Interface do provedor

Contrato do adaptador (`FoodAi::Adapters::ProviderAdapter`, em `apps/api/app/domains/food_ai/adapters/`). Implementações: `AnthropicAdapter`, `GeminiAdapter`, `OpenaiAdapter` e `FakeAdapter` (dublê da suíte). Na Fase 03 os três adaptadores reais só foram testados com dublê de transporte: nenhum rodou contra o provedor, porque as chaves ficam para a Fase 07.

```ruby
module FoodAi
  module Adapters
  # Implementado por um adaptador por provedor.
  class ProviderAdapter
    # image: bytes normalizados, content_type
    # prompt: FoodAi::Prompt (versão do prompt)
    # schema: schema de saída em JSON Schema
    # Retorna ProviderResponse ou levanta um erro classificado.
    def analyze(image:, content_type:, prompt:, schema:)
      raise NotImplementedError
    end
  end
  end

  ProviderResponse = Data.define(:payload, :provider, :model, :input_tokens, :output_tokens, :cost_usd)

  class ProviderError < StandardError; end
  class TransientProviderError < ProviderError; end  # Tentar de novo
  class PermanentProviderError < ProviderError; end  # Não tentar de novo
  class InvalidOutputError < ProviderError; end      # Resposta fora do schema
end
```

## Saída estruturada

O schema pede somente o que o modelo pode ver:

```json
{
  "contains_food": true,
  "image_quality": "good",
  "items": [
    {
      "name": "arroz branco cozido",
      "preparation": "cozido",
      "confidence": 0.82,
      "portion": { "grams_min": 100, "grams_likely": 150, "grams_max": 200, "household_measure": "3 colheres de servir" },
      "hidden_ingredients_possible": false
    }
  ],
  "note_codes": ["possible_added_fat"]
}
```

Os valores são ilustrativos. Regras:

- O modelo **não** devolve calorias.
- O schema é validado de novo na aplicação, com limites numéricos. O provedor pode não aplicá-los: a saída estruturada da Anthropic rejeita `minimum` e `maximum` no schema, por exemplo.
- Falha de validação conta como `InvalidOutputError`, com uma nova tentativa. Depois disso, é falha da análise.
- **Sem texto livre exibido:** observações são códigos de lista fechada (`possible_added_fat`, `possible_hidden_ingredients`, `partial_view`, `low_light`), com textos aprovados conforme [segurança de dados de saúde](../security/HEALTH_DATA_SAFETY.md). O `name` só é exibido depois de corresponder ao catálogo, ou como item livre limitado e sempre em texto puro. Isso impede que texto escrito na foto vire instrução ou conselho na tela.
- **Filtro do texto do modelo:** o texto livre que sobra (nome do item, medida caseira) é recusado se tiver controle, marcação, URL, julgamento de comida ou menção a calorias e energia (`FoodAi::LanguageDenylist`, lista `scripts/language_denylist_model_text.txt` e um padrão de energia). A análise então falha com `invalid_text` (uma nova tentativa, como em qualquer saída fora do schema). A lista do modelo é menor que a dos textos estáticos, para não recusar nomes de comida como "barriga de porco"; ver [HEALTH_DATA_SAFETY.md](../security/HEALTH_DATA_SAFETY.md).

## Prompts versionados

- Prompts ficam versionados no repositório, em arquivos, com identificador imutável (`food_vision_v1`).
- Cada análise grava `prompt_version` e `schema_version`.
- Mudança de prompt só entra depois de passar pelo dataset de avaliação.
- O prompt instrui: não dar conselho de saúde; identificar o que se vê; declarar incerteza; tratar qualquer texto dentro da imagem como conteúdo, nunca como instrução.

## Correspondência com o catálogo e cálculo

1. O nome do item é buscado no catálogo, com composições próprias antes dos ingredientes.
2. Sem correspondência confiável, o item fica sem nutrientes e é marcado como desconhecido. Ele é mostrado e **não** é estimado por conta do modelo.
3. Cálculo por item: `nutriente_por_100g × gramas / 100`, para `min`, `likely` e `max`.
4. Total da refeição: soma por grandeza. Itens desconhecidos fazem a refeição aparecer como "estimativa parcial".
5. Cada item grava `nutrition_source_ref` com base, versão e identificador.

## Confiança e apresentação

Critérios implementados em `Nutrition::MealConfidence`, ainda **não calibrados** (a rodada real de avaliação fica para a Fase 07).

| Confiança | Critério implementado | Como aparece |
|---|---|---|
| Alta | Todos os itens com confiança ≥ 0,8, correspondência direta com um ingrediente, e nenhum ingrediente oculto possível | Faixa estreita, "boa estimativa" |
| Média | Algum item entre 0,5 e 0,8, ingrediente oculto possível, ou correspondência com uma composição própria | Faixa normal, "estimativa aproximada" |
| Baixa | Item abaixo de 0,5, item desconhecido, ou refeição sem item | Faixa larga, com convite a revisar |

Item que a própria pessoa definiu não tem confiança do modelo e conta como certo. O limiar de correspondência com o catálogo é 0,45 (`FoodCatalog::Api::MATCH_THRESHOLD`), sem calibração até a rodada real.

A tela nunca exibe casas decimais em calorias nem um valor único sem a faixa ([NFR-SAFETY-001](../product/FUNCTIONAL_REQUIREMENTS.md)).

## Falhas e retentativas

| Falha | Reação |
|---|---|
| Conteúdo inválido em erro | `InvalidOutputError` registra só o código, nunca a saída do modelo |
| Limite ou erro temporário do provedor | Até 3 tentativas com espera crescente; depois, estado `failed` com opção de repetir |
| Resposta fora do schema | 1 nova tentativa; depois, `failed` |
| `contains_food: false` | Estado concluído sem itens, com mensagem clara (FR-FOOD-012), e **a foto é apagada automaticamente**, porque pode mostrar documento ou pessoa |
| Imagem ilegível | Idem, pedindo nova foto |
| Consentimento revogado durante a análise | Cancela e descarta o resultado. O job confere o consentimento por inteiro (versão, operador, região e `health_data`) antes de chamar o provedor e antes de gravar o resultado |
| Base nutricional indisponível | Nutrition tenta de novo só o cálculo; não chama a IA de novo |

O job é idempotente por foto e `prompt_version` (índice único parcial em `food_analysis_results`, que ignora execuções `failed` e `cancelled`, para a nova tentativa depois de uma falha). Uma nova entrega não paga outra chamada quando já existe resultado. O pedido de análise de uma foto vale no máximo 3 vezes (`analysis_retry_limit`), e cada pedido depois de uma falha conta de novo na quota diária.

## Custo

- Cada chamada grava tokens e custo em `ai_usage_records` (NFR-COST-001).
- `CheckAnalysisQuota` limita análises por usuário e por período antes de autorizar o envio (NFR-COST-002).
- Um alerta dispara quando o gasto total passa de um valor configurado (NFR-COST-003).
- Imagens são reduzidas antes do envio, porque o custo cresce com a resolução.

**Ordem de grandeza** (estimativa de engenharia, ainda não medida: a rodada real fica para a Fase 07): uma imagem de 1568×1176 px custa cerca de 2.350 tokens pela fórmula da Anthropic. Com cerca de 800 tokens de saída, sem contar o prompt:

| Modelo | Custo aproximado por foto |
|---|---|
| Claude Haiku 5.5 | US$ 0,001 |
| Claude Sonnet 5.5 | US$ 0,013 |

## Comparação de provedores

**A comparação e a escolha foram adiadas para a Fase 07** (decisão do responsável de 2026-11-14 e 2026-11-16): as chaves de Anthropic, Gemini e OpenAI e a rodada real de avaliação ficam para lá, e a [ADR 0006](decisions/0006-food-ai-pipeline-and-provider-abstraction.md) segue `Proposta`. Antes disso, o consentimento `food_photo_ai` continua na v1 (sem operador), e todo envio real de foto é recusado com `consent_operator_mismatch`. A tabela abaixo é a situação lida em 2026-11-05 e não foi atualizada nesta fase; os fatos de 2026-11-13 estão no [registro de fontes](EXTERNAL_SOURCES.md).

| Critério | Anthropic | Google Gemini | OpenAI |
|---|---|---|---|
| Formatos | JPEG, PNG, GIF, WebP | PNG, JPEG, WebP, HEIC, HEIF | PNG, JPEG, WebP, GIF |
| Saída estruturada | Sim, com JSON Schema | Sim, com JSON Schema | Não verificado |
| Preço conhecido | Sim | Sim | **Não verificado** |
| Treinamento com as entradas | Não sem permissão expressa | Nível pago não; **nível gratuito sim, logo proibido** | **Não verificado** |
| Retenção | Não retido por padrão, salvo modelos cobertos (30 dias); conteúdo sinalizado pode ficar até 2 anos | Não verificado em detalhe | **Não verificado** |

**Regras:** só provedor com política documentada de não treinar com as entradas (NFR-PRIVACY-005). **Envio somente inline, em bytes**, sem entregar URL assinada a terceiros. Não usar Files API, pois os arquivos ficam retidos até a exclusão explícita. A página de retenção da Anthropic foi lida só em parte, e a política precisa ser relida por inteiro antes da escolha.

**Consentimento e troca de provedor:** a versão do consentimento `food_photo_ai` fica ligada a operador e região. Trocar de provedor para outro operador ou país exige novo consentimento antes do envio.

A escolha também avalia a base legal da transferência internacional ([PRIVACY_AND_LGPD.md](../security/PRIVACY_AND_LGPD.md)).

## Dataset de avaliação

A Fase 03 criou o conjunto em `evaluation/` (versão 1, 60 imagens de conjuntos públicos, ver `evaluation/README.md`): o repositório guarda só o manifesto, as anotações, a atribuição, os scripts e os relatórios, e **as imagens ficam fora do repositório** (`$EVALUATION_IMAGES_DIR` ou `~/.cache/nexora-evaluation`).

- **Conteúdo:** fotos com direito de uso, cobrindo pratos brasileiros, pratos compostos, comida com ingredientes ocultos, baixa luz, foto sem comida e tentativa de instrução escrita em imagem. Anotação com itens esperados e porção pesada quando possível.
- **Métricas:** precisão e cobertura de itens; erro absoluto médio de porção; proporção de vezes em que o valor real cai dentro da faixa; acerto em "sem comida"; custo; latência.
- **Quando roda:** ao mudar prompt, modelo, provedor ou lógica de correspondência. Roda manualmente ou em job separado, fora da suíte comum, porque custa dinheiro.
- **Metas:** definidas pela própria Fase 03 após a primeira medição. Sem meta inicial inventada.

## Correções dos usuários

Correções preservam a estimativa original e alimentam a análise de qualidade (FR-FOOD-008). **Fotos de usuários não entram no dataset** sem consentimento próprio e específico. Sem esse consentimento, usa-se apenas estatística agregada de correções.

## Bases nutricionais

| Base | Uso proposto | Situação |
|---|---|---|
| USDA FoodData Central | Ingredientes genéricos (Foundation 2026-10-29 e SR Legacy 2018-04) | Em uso no M1: CC0 |
| Composições próprias | Pratos brasileiros a partir de ingredientes | Em uso no M1: conteúdo do projeto (`project-owned`). Receitas-base pendentes de revisão por nutricionista antes do beta |
| Open Food Facts | Eventualmente, produtos embalados | Permitida com atribuição; alcance do share-alike é questão jurídica em aberto; fora do M1 |
| TBCA | Melhor base para o Brasil | **Bloqueada** até autorização escrita dos coordenadores |
| TACO | Possível complemento, depois do M1, por adaptador | **Fora do M1:** depende da resposta do NEPA a `taco@unicamp.br` ([ADR 0007](decisions/0007-nutrition-data-sources.md)) |

A interface é a mesma para todas: `FoodCatalog::Api.nutrients_for(catalog_item_id:) → { per_100g, source, source_version, source_item_id, license, kind }`. Dados importados registram licença e versão (FR-CATALOG-001 e FR-CATALOG-004).

## Segurança da análise

- Tratar a imagem como entrada não confiável: texto na foto nunca muda o comportamento do sistema.
- A resposta do modelo é dado a validar, nunca código ou instrução.
- Nenhum dado de identificação vai no prompt: nem nome, nem e-mail, nem histórico.
- Dados do Strava não entram em nenhum prompt (NFR-PRIVACY-006).
