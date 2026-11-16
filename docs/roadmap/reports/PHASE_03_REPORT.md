# Relatório da Fase 03 — Food AI

- **Data:** 2026-11-16
- **Estado:** `Em revisão`. O código está pronto e verificado. A prova real com provedor de IA está pendente, porque as chaves foram adiadas pelo responsável para a Fase 07.
- **Branch:** `phase/03-food-ai`, 41 commits sobre `main` `5357167`, sem push.
- **Plano:** [2026-11-13-food-ai.md](../../superpowers/plans/2026-11-13-food-ai.md). **Design:** [2026-11-13-food-ai-design.md](../../superpowers/specs/2026-11-13-food-ai-design.md).

## 1. Resumo

O caminho inteiro da foto à estimativa está implementado e testado, com dublês no lugar dos provedores de IA:

- **Envio da foto:**
  - URL assinada de 15 minutos, com tipo e tamanho assinados, para um armazenamento privado (SeaweedFS no desenvolvimento).
  - Consentimento `food_photo_ai` ligado a empresa e país, conferido na autorização e dentro do job.
  - Cota de 20 envios por dia no fuso da pessoa, limite de 3 novas análises por foto e limite de requisições.
- **Normalização:** o tipo é conferido pelos bytes e a foto vai até 10 MB e 40 megapixels. EXIF e todos os metadados são removidos, e a orientação é aplicada. A saída é JPEG de até 1.568 px. HEIC e HEIF são aceitos e convertidos. O objeto guardado é substituído pela versão limpa.
- **Food AI:**
  - Prompt versionado e imutável.
  - Validação estrita da saída: sem calorias e sem campos a mais, com limites numéricos.
  - Filtro de linguagem no texto do modelo.
  - Três adaptadores (Anthropic, Gemini, OpenAI) sobre `Net::HTTP`, sem SDK.
  - Novas tentativas com espera, idempotência por foto e versão do prompt, registro de custo por chamada e evento `food_analysis.completed` pela outbox.
- **Nutrition:**
  - Correspondência com o catálogo e faixas calculadas a partir das gramas, com origem por item, confiança e "estimativa parcial".
  - Confirmação com um toque.
  - Correção que preserva o original.
  - Itens livres, registro manual, histórico paginado sem N+1 e exclusão.
  - Eventos `food_entry.confirmed` e `food_entry.deleted`.
- **Food Catalog:** 179 ingredientes do USDA FoodData Central (CC0) com nome em português, e 34 pratos brasileiros como composição própria. A busca ignora acento e prefere o alimento cozido. TACO e TBCA ficaram fora.
- **Rotinas:**
  - Foto apagada 30 dias após a análise.
  - Envio abandonado apagado em 1 hora, e foto sem análise em 24 horas.
  - Análises e vínculo de custo por 90 dias.
  - Recuperação de refeições presas, varredura de objetos e alerta mensal de gasto.
  - Exportação e exclusão de conta alcançando tudo isso.
- **App móvel:**
  - Câmera e galeria, consentimento antes da primeira foto e cópia local que sobrevive à falha de rede, com reenviar ou descartar.
  - Acompanhamento da análise, resultado em faixas e correção com busca.
  - Apagar refeição e itens, registro manual e histórico por dia.
- **Linguagem:** verificação automática dos textos estáticos contra a lista de `HEALTH_DATA_SAFETY.md` e teste de que o contrato não tem meta, limite nem total de calorias.
- **Avaliação:** dataset de 60 imagens públicas com licença conferida (Nutrition5k, MyFood, UNIFEI, Wikimedia CC0, mais 5 derivadas), script reprodutível, métricas testadas e relatório pré-provedor do catálogo.

O que **não** existe: nenhuma chamada a provedor real. As decisões do responsável de 2026-11-14 e 2026-11-16 adiaram as chaves da Anthropic, do Gemini e da OpenAI para a Fase 07.

## 2. Validação

Executado pelo controlador em 2026-11-16, no commit `a056bf8`.

| Comando | Código | Resultado |
|---|---|---|
| `bundle exec rspec` | 0 | 1.221 exemplos, 0 falhas (inclui o armazenamento real local com SeaweedFS) |
| `bundle exec rubocop` | 0 | 312 arquivos, sem ofensas |
| `bundle exec brakeman -q --no-pager -w2` | 0 | Nenhum aviso |
| `bundle exec bundle-audit check --update` | 0 | Nenhuma vulnerabilidade. Antes, 7 alertas no Puma 8.0.2, publicados durante a fase; corrigido para 8.0.3 em `5093c63` |
| `npm run check -w @app/contracts` | 0 | Tipos gerados conferem com o contrato |
| `npm audit --audit-level=high` | 0 | Nenhum alerta alto ou crítico; 33 moderados e 1 baixo em ferramentas de desenvolvimento |
| Mobile: typecheck, lint, testes | 0, 0, 0 | 186 testes |
| Web: typecheck, lint, testes, build | 0, 0, 0, 0 | 67 testes |
| `python3 scripts/check_language.py` | 0 | Nenhum termo proibido |
| `bash scripts/test-check-language.sh` | 0 | 69 testes |
| `bash scripts/verify-harness.sh` | 0 | Aprovado |
| `bash scripts/test-verify-harness.sh` | 0 | 93 testes |
| `ruby evaluation/fetch.rb` | 0 | 60 de 60 imagens com sha256 conferido (2026-11-14) |
| `bin/rails runner ../../evaluation/run.rb` sem chave | 1 | Recusa clara, sem rede (comportamento esperado) |
| CI do GitHub | — | Não executado: sem push autorizado. Os passos novos do CI (SeaweedFS por `docker run`, `libvips42t64` e `libheif-plugin-libde265`) não rodaram em runner |

**Demonstrações reais:** nenhuma. Todas dependem do provedor ou do consentimento v2, ver a seção 6.

## 3. Critérios

| Critério | Evidência | Situação |
|---|---|---|
| `AC-03-01` | `spec/integration/object_storage_spec.rb` contra o SeaweedFS real: GET sem assinatura recusado, URL vencida recusada, tamanho diferente do assinado recusado. `spec/domains/food_ai/normalize_photo_spec.rb` (GPS presente antes e ausente depois, inclusive HEIC). `run_analysis_spec.rb` confere que o objeto guardado é o normalizado | Comprovado (armazenamento local; o de produção será escolhido no M1, ADR 0015) |
| `AC-03-02` | Pipeline completo com dublê (`run_analysis_spec.rb`, `apply_analysis_spec.rb`) | **Parcial.** Sem demonstração com provedor real |
| `AC-03-03` | `calculator_spec.rb`, `apply_analysis_spec.rb` (`nutrition_source_ref` por item), `validate_output_spec.rb` (calorias proibidas em qualquer profundidade) | Comprovado |
| `AC-03-04` | `food_entry_management_spec.rb`, `concurrency_spec.rb`, testes do app `result.test.tsx` e `resultActions` | **Parcial.** Sem demonstração no app |
| `AC-03-05` | Contagem de consultas igual para 5 e 15 refeições; exclusão apaga itens, foto e análises, inclusive por evento `food_entry.deleted` | Comprovado |
| `AC-03-06` | `no_food` e `unreadable` sem números e com a foto apagada (`run_analysis_spec.rb`); registro manual (`food_entry_management_spec.rb`) | **Parcial.** A parte "e dataset" não rodou contra provedor |
| `AC-03-07` | Três adaptadores com dublê (`http_adapters_spec.rb`); provedor por configuração; Nutrition não conhece o provedor (verificação de limites); prompt, modelo, resposta e custo gravados por análise | **Parcial.** Faltam dois adaptadores reais e a comparação |
| `AC-03-08` | Dataset reprodutível e métricas testadas (`evaluation/`, `spec/evaluation`) | **Parcial.** Sem primeira medição e sem metas de qualidade |
| `AC-03-09` | Specs de busca e composições; só `usda_fdc` e `project` aceitos | **Parcial.** ADR 0007 pronta para o seu aceite |
| `AC-03-10` | Portão de consentimento com versão, empresa e país, na autorização e no job; inspeção do corpo enviado aos adaptadores (sem EXIF, nome ou e-mail); políticas relidas em 2026-11-13 | **Parcial.** Nenhum provedor escolhido, e o texto v2 não existe |
| `AC-03-11` | `spec/integration/food_analysis_logging_spec.rb` (sucesso, falha e `InvalidOutputError`, nos logs e no Sentry); `unlogged_spec.rb` | Comprovado |
| `AC-03-12` | Agregação por pessoa (`retention_spec.rb`, `FoodAi::Api.usage`); `429 analysis_quota_exceeded` com `Retry-After`; alerta (`spend_alert_spec.rb`) | **Parcial.** Sem demonstração, porque o envio real é recusado até a v2 |
| `AC-03-13` | `no_calorie_goal_spec.rb`; `check_language.py` no CI; filtro do texto do modelo; revisão das telas pelo revisor mobile | **Parcial.** O dataset com instrução na imagem não rodou |
| `AC-03-14` | Medição de p95 implementada e testada | **Sem evidência.** Nenhuma medição |
| `AC-03-15` | Testes de componente: permissão negada, rede, os estados, `429`, laço de consentimento | **Parcial.** Sem demonstração no app |
| `AC-03-16` | ADR 0007 pronta para aceite; ADR 0006 `Proposta`, adiada para a Fase 07 | **Parcial** |
| `AC-03-17` | 30 dias decididos e aplicados (`photo_retention_job`, `retention_spec.rb`); o app apaga as cópias ao concluir, ao sair, no 401 e ao excluir a conta (`localCopy.test.ts`, `sessionCleanup.test.ts`); prazo em `DATABASE_DESIGN.md` | Comprovado |

Resumo: 5 comprovados, 11 parciais e 1 sem evidência. Quase todas as lacunas têm a mesma causa: a ausência de chave de provedor.

## 4. Revisões

**Durante a execução.** Cada uma das 16 tarefas teve uma revisão de escopo e qualidade depois da implementação. Em 12 tarefas houve uma rodada de correção, sempre com nova revisão em seguida. Nenhuma passou da primeira rodada. Os pontos mais relevantes corrigidos:

- `Content-Length` fora da assinatura do PUT;
- exportação com `raw_response`;
- erros de rede escapando sem código;
- custo zero gravado em silêncio;
- `give_up` marcando falha numa foto já analisada;
- foto órfã quando o armazenamento falha na exclusão;
- fotos sem análise guardadas para sempre;
- a lista de linguagem enfraquecida para acomodar um texto aprovado.

**No encerramento,** sobre a branch inteira:

| Revisor | Achados | Tratamento |
|---|---|---|
| Revisão final (Opus) | 0 críticos, 6 importantes. Os principais: envio vencido perdia a foto; app sem apagar refeição e itens; texto do modelo sem filtro; novas análises contornando a cota; corrida com a exclusão de conta; laço de consentimento sem a v2 | Corrigidos nas levas A (backend) e B (app), revistos e aprovados |
| `software-architect` | 4 importantes: Nutrition sem eventos; exclusão síncrona com janela de perda; adiamento sem registro e conflito com a ADR 0016; ADR 0007 sem a decisão escrita | Eventos e exclusão pela outbox (leva A). Documentos e ADRs atualizados (leva C). O conflito com o M1 é decisão sua (seção 6) |
| `backend-reviewer` | 3 importantes: reanálise sem teto; `Sidekiq::Shutdown`; custo perdido no rollback | Corrigidos (leva A) |
| `security-reviewer` | 4 importantes: job sem conferir empresa e país; `PRIVACY_AND_LGPD.md` desatualizado; texto do modelo sem filtro; exclusão de conta durante a análise. Mais 8 pendências jurídicas | Corrigidos (levas A e C). As pendências foram para o documento de LGPD |
| `frontend-mobile-reviewer` | 3 importantes: cópia do seletor nunca apagada; erro escondido no "Tentar de novo"; foto perdida em 5xx e 429 | Corrigidos (leva B) |
| `qa-reviewer` | Tabela de critérios. Dois apontamentos estavam errados (teste real de armazenamento e agregação de custo, que existem) | Tabela incorporada à seção 3. Os apontamentos errados foram recusados com o caminho dos arquivos |

Também foi corrigido no encerramento: apagar uma refeição exigia o consentimento `health_data` e passou a não exigir (`a056bf8`), pelo direito de eliminação.

**Achados de processo.** Em partes das Tarefas 5, 7, 10 e 13, os testes foram escritos depois do código, contra a regra de TDD. Nos casos verificados, uma mutação do código fez o teste falhar. Em todas as rodadas de correção, o teste falhou antes do código. Um subagente foi interrompido pelo limite de uso e retomado sem perda.

## 5. Verificado e apenas criado

**Verificado por execução:**
- as suítes da seção 2;
- o armazenamento real local, com seis provas de URL assinada;
- a normalização com a libvips local, inclusive HEIC sintético;
- o download e o sha256 das 60 imagens;
- a recusa do script de avaliação sem chave;
- os números do catálogo contra o dataset: 28 nomes certos e 1 errado no limiar de 0,45.

**Apenas criado, sem execução real:**
- os três adaptadores contra as APIs reais, com o formato das respostas marcado como "verificado em parte" no registro de fontes;
- o comando `food_ai:smoke`;
- a rodada de avaliação com provedor;
- os passos novos do CI;
- o app em aparelho ou emulador;
- HEIC real de iPhone (HEVC);
- HEIF com várias imagens.

## 6. Pendências

**Para você decidir agora:**
1. **Aprovar a fase com as lacunas da seção 3,** todas ligadas à falta de chave: AC-03-02, 04, 06, 07, 08, 09, 10, 12, 13, 14, 15 e 16. O Definition of Done da fase exige "prova real com o provedor", então isso é uma lacuna aceita, como o AC-02-08 na Fase 02.
2. **Aceitar as ADRs 0007** (bases nutricionais) **e 0019** (armazenamento e processamento de imagem). As duas estão prontas.
3. **Ordem do M1.** O M1 (beta com foto) vem antes da Fase 07, mas depende de:
   - uma chave de provedor;
   - a rodada real de avaliação;
   - a ADR 0006 aceita;
   - o texto v2 do consentimento aprovado;
   - uma demonstração real;
   - a revisão das composições por nutricionista.

   Sem a v2, todo envio de foto é recusado, e o app mostra "A análise por foto ainda não está disponível". Os pré-requisitos estão em `MILESTONE_M1_CLOSED_BETA.md`. A escolha é sua: trazer a chave para antes do M1, ou mudar a ordem por ADR (a 0016 está aceita).
4. **Confirmar que, quando a sessão expira, o app apaga as fotos ainda não enviadas.** Interpretei o seu "pode fazer" de 2026-11-14 como "manter assim".

**Pendências técnicas para o próximo trabalho com provedor (Fase 07 ou antes do M1):**
- spec próprio do `HttpTransport`;
- truncamento (`max_tokens`) com código próprio, e conferir se 4.096 tokens de saída bastam;
- regex de injeção incompleta ("kcal: 50", "cinquenta calorias");
- `generateContent` legado contra a API Interactions do Gemini;
- HEIC real de iPhone e HEIF com várias imagens;
- calibração do `MATCH_THRESHOLD` com nomes reais dos modelos.

**Pendências jurídicas** (detalhe em `docs/security/PRIVACY_AND_LGPD.md`):
- diferença na política de retenção da Anthropic;
- região do Gemini;
- hipótese do art. 33;
- foto já analisada depois da revogação;
- alcance do direito de acesso (a exportação não traz os bytes da foto nem o `raw_response`);
- pessoas e menores nas fotos;
- dados depois da revogação de `health_data`;
- licença LGPL-2.1 da libvips num SaaS;
- backup do iOS das fotos pendentes no aparelho.

**Pendências de produto e app:**
- Depois de revogar `health_data`, a pessoa não chega à tela de apagar a refeição: o histórico fica bloqueado, embora a API já permita apagar.
- Revisão das 34 receitas por nutricionista antes do beta.
- Resposta do NEPA sobre a TACO.

**Achados menores registrados e não corrigidos** (risco baixo, avaliados pela revisão final):

- **Catálogo:**
  - o banco não impõe o tipo `ingredient` nem a soma de 100 g nas composições, só a carga;
  - o `fdc_id` é resolvido pela versão mais nova entre releases;
  - o `unlogged` ignora loggers sem `silence`;
  - a lista `DRY_INGREDIENTS` é manual.
- **Validação:**
  - a heurística de URL usa `\w` ASCII;
  - o spec de preços duplica a tabela;
  - provedor e modelo do custo são validados só no código.
- **Adaptadores:**
  - constante global no rake de smoke;
  - `missing_usage` aparece em vez de `not_an_object` numa resposta 200 ilegível.
- **Pipeline:**
  - a falha de `perform_in` ou do `persist` pode custar uma chamada a mais;
  - o pedido de análise conta mesmo se o enfileiramento falhar;
  - o ramo de reaproveitar execução vencida no `give_up` não tem spec;
  - o log do `SidekiqCorrelation` não está no spec de logs;
  - o `ApplyAnalysis` não confere a dona da análise;
  - o `StuckEntriesJob` pode devolver a cota numa janela mínima;
  - a regra de 24 horas pode apagar a foto no instante de uma nova tentativa (corrige-se sozinha);
  - a varredura repete a exclusão diariamente por até 7 dias;
  - o `rate_limit` é por processo sem cache compartilhado;
  - `FoodAi::Api.photo_urls` ficou sem uso.
- **Nutrition:**
  - `corrected_from_item_id` sem FK;
  - repetir o registro manual fora da janela de 30 dias responde 422;
  - validação de unicidade redundante.
- **Linguagem:**
  - a busca é por linha;
  - a linha liberada fica isenta de todos os termos;
  - parâmetros de path e de operação são checados separadamente.
- **App:**
  - o erro de apagar não aparece nos estados `pending` e `processing`;
  - a detecção do laço de consentimento não é zerada numa falha de envio;
  - uma falha no `rename` pode deixar uma cópia sem metadado até o logout;
  - faltam testes de limpeza do polling e de toque duplo.
- **Avaliação:** um provedor que aborta perde os resultados dos anteriores.

## 7. Decisões tomadas durante a execução

**Decisões do responsável:**

| Data | Decisão |
|---|---|
| 2026-11-13 | Provedores candidatos: Anthropic, Gemini e OpenAI |
| 2026-11-13 | Bases: USDA mais composições, TACO depois |
| 2026-11-13 | Prazo de 30 dias para as fotos |
| 2026-11-13 | Dataset de conjuntos públicos, sem fotos próprias |
| 2026-11-13 | Escolhas técnicas e design aprovados |
| 2026-11-14 | HEIC convertido no backend |
| 2026-11-14 | Catálogo prefere o alimento cozido |
| 2026-11-14 | Sessão expirada apaga as fotos não enviadas (interpretação, ver o item 4 da seção 6) |
| 2026-11-14 e 2026-11-16 | Chaves de IA adiadas para a Fase 07 |

**Decisões do controlador, com o custo se estiverem erradas:**
1. A foto passou a ser do Food AI (`food_photos`), e não do Nutrition, por causa dos limites entre domínios. Custo: nenhum funcional.
2. A ordem das tarefas mudou enquanto a libvips não estava instalada. Custo: nenhum.
3. A gem `image_processing` ficou de fora e só `ruby-vips` foi usada, para não gravar fotos em arquivos temporários. Custo: adicionar a gem depois.
4. Busca no catálogo, envio e demais rotas de comida exigem `health_data`. A exceção é apagar a refeição. Custo: tirar um `before_action`.
5. Normalização por coluna `name_search` em vez de função `unaccent`. Custo: nenhum funcional.
6. Índice único parcial por foto e versão do prompt, para permitir tentar de novo depois de uma falha. Custo: ajustar uma migration.
7. Exportação e exclusão das tabelas novas foram adiantadas da Tarefa 10. Custo: refatoração.
8. Erros sem código foram elevados a importantes em várias revisões. Custo: rodadas extras.
9. A verificação de inicialização só derruba a produção com um provedor configurado. Custo: uma checagem a mais.
10. Imagens de avaliação ficam em `~/.cache/nexora-evaluation`. Custo: nenhum.
11. Dois apontamentos da revisão de QA foram recusados, com os arquivos que os contradizem. Custo: nenhum.
12. A leva de correção do encerramento foi dividida em backend, app e documentos. Custo: três despachos.
13. As fotos pendentes ficam em `documentDirectory`, com `allowBackup: false` no Android. Custo: uma configuração.
14. O filtro do texto do modelo usa um subconjunto de julgamento, para não recusar "barriga de porco". Custo: uma frase de julgamento pode passar (o prompt também a proíbe).
15. As ADRs 0007 e 0019 ficam como prontas para aceite, sem a marca de aceitas. Custo: trocar uma palavra.
16. Apagar a refeição não exige `health_data`. Custo: um `before_action`.

## 8. Próximo passo

Para aprovar a fase com as lacunas, envie:

> Aprovo a Fase 03, aceitando as lacunas dos AC-03-02, 04, 06, 07, 08, 09, 10, 12, 13, 14, 15 e 16 por falta de chave de provedor, com a prova real antes do M1. Aceito as ADRs 0007 e 0019.

Inclua também a sua escolha sobre a ordem do M1 (item 3 da seção 6) e a confirmação do item 4. Depois da aprovação, a próxima linha do roadmap é a 05.1:

> Vamos iniciar a fase 05.1.

O push da branch e o PR para `main` só acontecem com a sua autorização.
