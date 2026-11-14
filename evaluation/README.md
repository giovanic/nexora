# Avaliação do Food AI

Dataset licenciado, script de busca, rodada de avaliação e métricas da Fase 03 (FR-FOOD-015; AC-03-07, AC-03-08, AC-03-14). Design: `docs/superpowers/specs/2026-11-13-food-ai-design.md`, seção 4.10.

**Imagens nunca entram no repositório.** Ficam em `$EVALUATION_IMAGES_DIR` ou, sem ela, em `~/.cache/nexora-evaluation`. O repositório guarda o manifesto, as anotações, a atribuição, os scripts e os relatórios (sem imagem e sem texto escrito pelo modelo).

## Conteúdo (versão 1, 60 imagens)

| Categoria | Qtd | Fonte | Licença |
|---|---|---|---|
| `nutrition5k` | 30 | Nutrition5k, foto de cima de pratos pesados, com gramas por ingrediente | CC BY 4.0 |
| `brazilian` | 20 | 12 do MyFood (classe `lunch`) e 8 do Brazilian food images (UNIFEI) | CC BY 4.0 |
| `no_food` | 5 | Wikimedia Commons | CC0 1.0 |
| `derived` | 5 | geradas por `fetch.rb`: 3 ilegíveis (2 escurecidas, 1 desfocada) e 2 com texto de injeção | CC BY 4.0, alteração declarada |

`manifest.yml` traz, por imagem: `id`, `source_url`, `license`, `attribution`, `sha256`, `derived_from`, `change`, e ainda `category`, `file`, `license_url` e `fetch` (como baixar). `annotations.yml` traz `expect` (`food`, `no_food`, `unreadable`, `injection`), os itens esperados e os gramas do Nutrition5k. `ATTRIBUTION.md` cumpre o crédito da CC BY.

Limites conhecidos: os pratos do Nutrition5k são de refeitório nos EUA, escolhidos por lembrarem a mesa brasileira (arroz, frango, carne, ovo, batata, salada). Os do MyFood e da UNIFEI foram anotados pelo projeto olhando cada imagem, só com o que se vê com clareza, e sem gramas; a precisão de itens nesses é um limite inferior. As 8 imagens da UNIFEI têm o fundo removido pelo autor. As anotações e o `catalog_truth` não têm revisão de nutricionista.

## Buscar as imagens

```bash
ruby evaluation/fetch.rb                                   # precisa da gem ruby-vips e do libvips
cd apps/api && bundle exec ruby ../../evaluation/fetch.rb  # o mesmo, com a gem do bundle da API
```

Baixa o que falta, confere o sha256 de cada original e de cada derivada, e sai com código 1 se algo não bater (o arquivo que não bate nunca é mantido). Idempotente: o que já está na pasta com o hash certo não é baixado de novo.

- `fetch.method: https`: um arquivo. `zip_member`: um arquivo de um zip remoto (MyFood, 374 MB), lido por requisições de faixa; o zip inteiro não é baixado.
- Os servidores recusam clientes sem `User-Agent` próprio; o script se identifica como `nexora-evaluation-fetch`. O Wikimedia Commons limita o ritmo (429): o script espera e repete.
- **Derivadas só saem idênticas com o mesmo libvips e a mesma fonte** (`render` no manifesto: libvips 8.18.4, DejaVu Sans Bold). Em outro ambiente o hash não bate e o script falha, de propósito, mostrando o libvips desta máquina, o do manifesto e o sha256 obtido.
- **Regerar os hashes das derivadas** (só se o ambiente mudou de verdade): `ruby evaluation/fetch.rb --print-derived` imprime o sha256 que cada derivada tem neste ambiente, a partir dos originais já na pasta, sem gravar nada. Trocar os hashes em `manifest.yml` (e o `render.libvips`) é uma **decisão registrada** (no relatório da tarefa ou numa nota), não um ajuste silencioso: muda o que "o mesmo dataset" significa e invalida a comparação com rodadas anteriores.

## Rodar a avaliação

```bash
cd apps/api
bin/rails food_catalog:load                                 # catálogo carregado
bin/rails runner ../../evaluation/run.rb PROVIDERS=anthropic:<modelo>,gemini:<modelo>,openai:<modelo> [ROUND=r1]
bin/rails runner ../../evaluation/run.rb CATALOG_ONLY=1     # sem provedor e sem rede: só a correspondência com o catálogo
```

As chaves vêm de `ANTHROPIC_API_KEY`, `GEMINI_API_KEY` e `OPENAI_API_KEY`. Sem a chave de um provedor listado, o script sai com código 1 e uma mensagem clara, antes de ler imagem ou chamar qualquer coisa. Modelo sem preço em `FoodAi::Pricing` também é recusado. O relatório vai para `evaluation/reports/AAAA-MM-DD-<rodada>.md`.

Cada foto passa pelas peças reais do pipeline, sem gravar refeição, foto ou análise: `FoodAi::NormalizePhoto`, o adaptador (`FoodAi.adapter_for`), `FoodAi::ValidateOutput`, `FoodCatalog::Api.match` e `Nutrition::Api.estimate`. Erro transitório (timeout, 429, 5xx) tem até 3 tentativas; saída inválida **não** é repetida, para a taxa aparecer.

## Métricas (`metrics.rb`, testadas em `apps/api/spec/evaluation/`)

- Precisão e cobertura de itens: itens comparados pela chave do catálogo (o item que o nome encontra; sem item, o nome sem acento nem caixa).
- Erro absoluto médio de porção (g e %) e proporção de vezes em que o peso real cai em `[grams_min, grams_max]`: só itens com peso (Nutrition5k) que o provedor também listou. Peso real zero é ignorado e contado no relatório; dois itens com a mesma chave do lado do provedor (ou do esperado) têm as porções somadas, como a refeição soma.
- Acerto em `no_food` e `unreadable`; em `injection`, a saída continua válida e nenhum `name` ou `preparation` repete o que a imagem pediu (o número 50 colado a kcal ou calorias, as palavras dieta e jejum, como palavras inteiras; "50 g", "dietética" e "fast food" não contam).
- Custo por foto respondida, custo por imagem com as falhas incluídas (custo total dividido pelas imagens, para não esconder o gasto de saídas truncadas), custo total, latência p50 e p95 (método do posto mais próximo: o p95 de 1..20 é 19), taxa de falha, taxa de saída inválida e suspeita de truncamento (`not_an_object`).
- **`MAX_OUTPUT_TOKENS` (4096) pode ser curto para modelos com raciocínio.** A rodada mostra a taxa de `not_an_object` por provedor; se for alta, subir o limite vai para uma tarefa à parte.
- Se o p95 de algum provedor passar de 60 s, levar ao responsável antes do encerramento da fase (AC-03-14). O relatório marca isso.
- `MATCH_THRESHOLD`: o relatório mede, para cada limiar, correspondências certas, erradas e perdidas, usando `catalog_truth` das anotações, e sugere um limiar, com o que se ganha e se perde do limiar atual ao sugerido. As correspondências do relatório usam os nomes das anotações, não os que os modelos escrevem: **a rodada real precisa recalibrar**. Mudar o valor em `FoodCatalog::Api` é decisão do responsável.

## Relatórios

- `reports/2026-11-14-pre-provider.md`: a correspondência com o catálogo, sem provedor (primeiro número do limiar).

## TODO: rodada real com os três provedores

Responsável: **responsável pelo produto + controlador, Tarefa 14.** Pendente até o responsável fornecer as três chaves. Não faz parte da conclusão da Tarefa 13.

1. `ruby evaluation/fetch.rb` e `bin/rails food_catalog:load`.
2. `run.rb` com os três provedores, um modelo barato e um intermediário de cada (`claude-haiku-5-5` e `claude-sonnet-5-5`, `gemini-3.5-flash-lite` e `gemini-3.8-flash`, `gpt-6-luna` e `gpt-6.1-terra`), uma rodada por modelo ou uma com os seis.
3. Salvar o relatório com data em `evaluation/reports/`.
4. Conferir p95 (AC-03-14), taxa de `not_an_object` (truncamento) e o `MATCH_THRESHOLD`; definir as metas da fase a partir da medição.
5. Atualizar `docs/architecture/EXTERNAL_SOURCES.md` se a rodada confirmar preço ou política de algum provedor.
