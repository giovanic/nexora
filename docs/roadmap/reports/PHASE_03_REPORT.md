# Relatório da Fase 03 — Food AI

- **Data:** 2026-11-16
- **Estado:** `Concluída` em 2026-11-17, aprovada pelo responsável ("aprovo", em resposta à frase da seção 8) com a lacuna aceita dos AC-03-02, 04, 06, 07, 08, 09, 10, 12, 13, 14, 15 e 16: a prova real com provedor de IA fica para antes do M1, porque as chaves foram adiadas para a Fase 07. ADRs 0007 e 0019 aceitas.
- **Reabertura de 2026-11-25:** Groq como quarto provedor candidato, a pedido do responsável. Ver a [seção 9](#9-reabertura-de-2026-11-25-groq-como-candidata). `Concluída` de novo em 2026-11-25: "Aprovo a reabertura da Fase 03 (Groq), aceitando os AC-03-07, 08 e 14 como parciais."
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
| CI do GitHub, [PR #20](https://github.com/giovanic/nexora/pull/20) | — | Primeira execução (2026-11-17, depois da aprovação) reprovou `secrets`, `api` e `web`, ver "Defeitos de CI depois da aprovação" na seção 6. Depois das correções, [CI 44193601077](https://github.com/giovanic/nexora/actions/runs/44193601077) com 6 de 6 jobs verdes, incluindo SeaweedFS e libvips no runner |

**Repetido em 2026-11-17, no commit `44e8269` e com o worktree limpo, antes da aprovação:** `bundle exec rspec` (1.221 exemplos, 0 falhas), rubocop (312 arquivos, sem ofensas), brakeman (sem avisos), `npm run check -w @app/contracts`, mobile (typecheck, lint e 186 testes), web (typecheck, lint e 67 testes), `check_language.py`, `test-check-language.sh` (69 testes), `verify-harness.sh` e `test-verify-harness.sh` (93 testes), todos com código 0.

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
| `AC-03-07` | Três adaptadores com dublê (`http_adapters_spec.rb`); provedor por configuração; Nutrition não conhece o provedor (verificação de limites); prompt, modelo, resposta e custo gravados por análise | **Parcial.** Faltam dois adaptadores reais e a comparação. Em 2026-11-25: um adaptador real (Groq), ainda sem comparação (seção 9) |
| `AC-03-08` | Dataset reprodutível e métricas testadas (`evaluation/`, `spec/evaluation`) | **Parcial.** Sem primeira medição e sem metas de qualidade. Em 2026-11-25: primeira medição (Groq, 43 de 60 fotos); metas ainda não definidas (seção 9) |
| `AC-03-09` | Specs de busca e composições; só `usda_fdc` e `project` aceitos | **Parcial.** ADR 0007 pronta para o seu aceite |
| `AC-03-10` | Portão de consentimento com versão, empresa e país, na autorização e no job; inspeção do corpo enviado aos adaptadores (sem EXIF, nome ou e-mail); políticas relidas em 2026-11-13 | **Parcial.** Nenhum provedor escolhido, e o texto v2 não existe |
| `AC-03-11` | `spec/integration/food_analysis_logging_spec.rb` (sucesso, falha e `InvalidOutputError`, nos logs e no Sentry); `unlogged_spec.rb` | Comprovado |
| `AC-03-12` | Agregação por pessoa (`retention_spec.rb`, `FoodAi::Api.usage`); `429 analysis_quota_exceeded` com `Retry-After`; alerta (`spend_alert_spec.rb`) | **Parcial.** Sem demonstração, porque o envio real é recusado até a v2 |
| `AC-03-13` | `no_calorie_goal_spec.rb`; `check_language.py` no CI; filtro do texto do modelo; revisão das telas pelo revisor mobile | **Parcial.** O dataset com instrução na imagem não rodou |
| `AC-03-14` | Medição de p95 implementada e testada | **Sem evidência.** Nenhuma medição. Em 2026-11-25: p95 de 4,15 s, só Groq e 43 de 60 fotos (seção 9) |
| `AC-03-15` | Testes de componente: permissão negada, rede, os estados, `429`, laço de consentimento | **Parcial.** Sem demonstração no app |
| `AC-03-16` | ADRs 0007 e 0019 aceitas em 2026-11-17; ADR 0006 `Proposta`, adiada para a Fase 07 | **Parcial** (lacuna aceita: falta a 0006) |
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

**Lacuna aceita em 2026-11-17:** AC-03-02, 04, 06, 07, 08, 09, 10, 12, 13, 14, 15 e 16, sem prova real com provedor, a fazer antes do M1. Os itens 1 e 2 abaixo foram decididos pelo "aprovo" do responsável. **Os itens 3 e 4 continuam em aberto.**

**Para você decidir agora:**
1. *(Decidido em 2026-11-17: aprovado.)* **Aprovar a fase com as lacunas da seção 3,** todas ligadas à falta de chave: AC-03-02, 04, 06, 07, 08, 09, 10, 12, 13, 14, 15 e 16. O Definition of Done da fase exige "prova real com o provedor", então isso é uma lacuna aceita, como o AC-02-08 na Fase 02.
2. *(Decidido em 2026-11-17: aceitas.)* **Aceitar as ADRs 0007** (bases nutricionais) **e 0019** (armazenamento e processamento de imagem). As duas estão prontas.
3. **Ordem do M1.** O M1 (beta com foto) vem antes da Fase 07, mas depende de:
   - uma chave de provedor;
   - a rodada real de avaliação;
   - a ADR 0006 aceita;
   - o texto v2 do consentimento aprovado;
   - uma demonstração real;
   - a revisão das composições por nutricionista.

   Sem a v2, todo envio de foto é recusado, e o app mostra "A análise por foto ainda não está disponível". Os pré-requisitos estão em `MILESTONE_M1_CLOSED_BETA.md`. A escolha é sua: trazer a chave para antes do M1, ou mudar a ordem por ADR (a 0016 está aceita).
4. **Confirmar que, quando a sessão expira, o app apaga as fotos ainda não enviadas.** Interpretei o seu "pode fazer" de 2026-11-14 como "manter assim".

**Defeitos de CI depois da aprovação** (2026-11-17, todos só no runner; correção autorizada pelo responsável):
- `secrets`: 12 achados `generic-api-key` da senha fictícia de teste em specs. Os specs passaram a usar `IdentityHelpers::PASSWORD`, e os 12 achados exatos estão em `.gitleaksignore` (`37c6d8e`).
- `api`, 13 falhas: o `db:prepare` do CI semeava o catálogo no banco de teste novo. Os seeds não carregam o catálogo em teste, com spec de regressão (`9ac2fd2`).
- `api`, 8 falhas: sem codificador HEIF no Ubuntu 24.04. O CI instala os plugins (`bb9ca72`), e o HEIC girado virou arquivo fixo, porque a libvips 8.15 não grava `irot` a partir da orientação (`135640c`). Conferido em contêiner `ubuntu:24.04`: o produto abre o HEIC girado em pé e o normaliza sem EXIF.
- `web`: alerta GHSA-fc5q-39xc-vjpf do `picomatch` até 4.0.7, sem versão corrigida, também na `main`. A auditoria passou a ser julgada por alerta, com exceção datada (`edaff92`). **A exceção vence em 2026-12-17:** antes disso, atualizar o `picomatch` se houver correção, ou levar ao responsável a renovação.

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

## 9. Reabertura de 2026-11-25: Groq como candidata

- **Pedido:** mensagem do responsável de 2026-11-25: "sim pode reabrir e implementar", com a condição de usar modelo grátis.
- **Entrega:** [PR #21](https://github.com/giovanic/nexora/pull/21), mergeado pelo responsável em `main` `0db96af`. O fechamento está na branch `phase/03-groq-closeout`.

### 9.1 Resumo

- **Adaptador `groq`:** `GroqAdapter` chama a API de chat da Groq, compatível com a OpenAI, com a foto em base64 e JSON Schema estrito. O modelo é o `qwen/qwen3.8-27b`.
- **Modelo pedido primeiro:** o `openai/gpt-oss-120b` só lê texto. Ele não tem preço registrado e é recusado.
- **Preço:** o da tabela paga da Groq. No plano gratuito, o custo registrado é um teto, não o gasto real.
- **Avaliação:** aceita `groq` e a opção `PACE` (segundos entre fotos). `food_ai:smoke` aceita `PROVIDER=groq`.
- **Registro de uso:** o nome do modelo pode ter um prefixo, como `qwen/...`.
- **Puma:** subiu de 8.0.3 para 8.0.5, por GHSA-4v6q-hvv7-49h9 e GHSA-rhww-p99c-hgj9. Os dois alertas foram publicados depois do merge da fase e reprovavam a auditoria do CI.
- **Exceção do `npm audit` removida:** a GHSA-fc5q-39xc-vjpf (`picomatch`) foi retirada pelo GitHub em 2026-11-18.

### 9.2 Validação

Execuções do controlador em 2026-11-25, na `main` `0db96af`, salvo onde indicado.

| Comando | Código | Resultado |
|---|---|---|
| `bundle exec rspec` | 0 | 1244 exemplos, 0 falhas |
| `bundle exec rubocop` | 0 | 314 arquivos, sem ofensas |
| `bundle exec brakeman -q --no-pager -w2` | 0 | Nenhum aviso |
| `bundle exec bundle-audit check --update` | 0 | Nenhuma vulnerabilidade |
| `npm run check -w @app/contracts` | 0 | Tipos gerados conferem |
| Web: typecheck, lint, testes, build | 0, 0, 0, 0 | 67 testes |
| Mobile: typecheck, lint, testes | 0, 0, 0 | 186 testes |
| `npm audit` com `scripts/check_npm_audit.py` | 0 | Sem alerta alto ou crítico sem exceção. Avisou a exceção sem uso, que foi removida |
| `verify-harness`, `test-verify-harness`, `test-check-language`, `check_language` | 0, 0, 0, 0 | Aprovados; 93 testes do harness |
| CI do PR #21 (commit `06ab93b`) | n/a | 6 de 6 jobs verdes ([execução 45725967404](https://github.com/giovanic/nexora/actions/runs/45725967404)) |
| `food_ai:smoke`, `PROVIDER=groq`, foto pública `myfood-lunch-102` (CC BY 4.0) | 0 | `status=ok provider=groq model=qwen/qwen3.8-27b input_tokens=2362 output_tokens=442 cost_usd=0.0036576 items=5`. O custo confere com a tabela: 2362 × 0,80 + 442 × 4,00, por milhão de tokens |
| `evaluation/run.rb PROVIDERS=groq:qwen/qwen3.8-27b ROUND=groq-r1 PACE=30` | 0 | [Relatório](../../../evaluation/reports/2026-11-25-groq-r1.md): 43 de 60 fotos respondidas; as 17 últimas recusadas com `rate_limited` |
| `rspec spec/domains/food_ai/http_adapters_spec.rb` (branch de fechamento) | 0 | Testes novos de envelope sem escolha, conteúdo que não é texto e resposta cortada |

**Rodada `groq-r1` (43 fotos respondidas):**
- Saída inválida: 0%.
- Latência: p50 de 2,06 s e p95 de 4,15 s.
- Itens: precisão de 25,2% e cobertura de 26,8%, pela chave do catálogo.
- Porção: erro médio de 22,5 g (30,6%), com o peso real dentro da faixa em 85,7% dos pares pesados (28).
- Custo: US$ 0,0031 por foto respondida, como teto.

As 17 recusas vieram em sequência, a partir da 44ª chamada do dia (contando a do `smoke`). Isso é a cota diária do plano gratuito, não o limite por minuto. Ficaram sem medição todas as fotos `no_food`, `unreadable` e de injeção, e 7 das 20 brasileiras.

### 9.3 Critérios

| Critério | Evidência nova | Situação |
|---|---|---|
| `AC-03-07` | Um adaptador real (Groq) usado na rodada. Prompt, modelo e custo registrados pelo mesmo caminho dos outros. Nutrition não mudou | **Parcial.** O critério pede dois adaptadores reais comparados |
| `AC-03-08` | Primeira medição com data (`groq-r1`), reprodutível pelo mesmo comando | **Parcial.** As metas de qualidade, que são do responsável, ainda não foram definidas. A medição cobre 43 de 60 fotos |
| `AC-03-14` | p95 de 4,15 s | **Parcial.** Vale só para Groq, plano gratuito e modelo em prévia, sobre 43 fotos. Não generaliza a NFR-PERF-002 |

Os demais critérios da fase não mudaram.

### 9.4 Revisões

Os revisores leram o diff `e99fd2c..0db96af`. O `frontend-mobile-reviewer` não foi acionado, porque nenhum cliente mudou. Nenhum achado crítico.

| Agente | Achados importantes | Tratamento |
|---|---|---|
| `software-architect` | ADR 0006 e `AI_ARCHITECTURE.md` diziam "sem chamada real" | Corrigidos: registram a chamada de teste e a rodada, só com fotos públicas |
| `security-reviewer` | Treino no plano gratuito vem só do contrato, sem o DPA lido; retenção de até 30 dias e ZDR sem registro; transferência internacional sem pendência própria | Pendência 25 em `PRIVACY_AND_LGPD.md`: EUA, inferência sem local, DPA não lido, ZDR obrigatório antes de foto de pessoa. Comentário do adaptador corrigido |
| `backend-reviewer` | `PACE` vale para todos os provedores; faltam testes de `content` que não é texto, `choices` vazio e resposta cortada; 400 `json_validate_failed` vira falha permanente | README documenta o `PACE` global. Três testes novos, que passaram de primeira porque o comportamento já existia. O 400 fica como risco: não apareceu na rodada |
| `qa-reviewer` | AC-03-07, 08 e 14 continuam parciais; o relatório precisa da saída do `smoke` e do motivo do puma | Registrados nas seções 9.2 e 9.3 |

**Recusados, com o que os contradiz:**
- **`backend-reviewer`, "429 não é repetido":** `evaluation/runner.rb` repete erro transitório até 3 vezes.
- **`backend-reviewer`, "67 ofensas do RuboCop":** o `rubocop` da API dá 314 arquivos sem ofensa, e `evaluation/` fica fora da configuração.
- **`qa-reviewer`, "a espera do retry entra no p95":** `runner.rb` reinicia o relógio a cada tentativa e mede só a chamada que respondeu.

**Menores, sem mudança:**
- nenhuma trava impede ativar o modelo em prévia em produção (a documentação avisa);
- a chave de cada provedor aparece em três lugares;
- `PACE` aceita `"1_0"`;
- falta testar o limite de 64 caracteres com barra.

### 9.5 Verificado e apenas criado

- **Verificado contra a Groq:**
  - JSON estrito junto com imagem;
  - formato `choices[].message.content` e `usage.prompt_tokens`/`completion_tokens`;
  - preço calculado;
  - latência;
  - cota diária do plano gratuito.
- **Apenas com dublê:**
  - recusa (`message.refusal`), nunca observada;
  - 400 `json_validate_failed`;
  - recuperação de 429 por minuto.
- **Configuração da conta não verificável pelo código:** se o ZDR está ligado na Groq.

### 9.6 Pendências

1. **AC-03-07:** comparar com um segundo provedor real. A Fase 07 tem as chaves de Anthropic, Gemini e OpenAI.
2. **As 17 fotos sem medição:** o plano gratuito fica em cerca de 43 fotos por dia, e o dataset tem 60. Opções:
   Decisão do responsável em 2026-11-25: rodar só essas 17 fotos quando a cota renovar. A avaliação ganhou a opção `ONLY`, com teste. Comando:

   ```bash
   cd apps/api && set -a && . ~/.config/nexora/ai.env && set +a && \
     bin/rails runner ../../evaluation/run.rb PROVIDERS=groq:qwen/qwen3.8-27b ROUND=groq-r1b PACE=30 \
     ONLY=unifei-meal-0026,unifei-meal-0027,unifei-meal-0031,unifei-meal-0032,unifei-meal-0033,unifei-meal-0037,unifei-meal-0039,commons-cat-grass,commons-bicycle,commons-building-paulista,commons-mountain-wright,commons-lighthouse-kovalam,derived-dark-n5k,derived-dark-myfood,derived-blur-myfood,derived-injection-myfood,derived-injection-n5k
   ```
3. **Plano gratuito no beta:** com cerca de 43 fotos por dia na conta inteira, não atende 10 pessoas. Além disso, o modelo está em prévia.
4. **Metas de qualidade (AC-03-08):** decisão do responsável, agora com a primeira medição.
5. **ZDR na conta da Groq:** ligar e registrar antes de qualquer foto de pessoa (pendência jurídica 25).
6. **Limiar de correspondência do catálogo:** a ressalva do relatório de 2026-11-14 continua. A precisão de 25% mede também nomes do modelo que o catálogo não acha.

### 9.7 Próximo passo

Para concluir de novo a Fase 03, com as lacunas acima, envie:

> Aprovo a reabertura da Fase 03 (Groq), aceitando os AC-03-07, 08 e 14 como parciais.

Depois disso, a 05.1, cujo plano você aprovou em 2026-11-25 com execução por subagentes, passa a `Em desenvolvimento`.
