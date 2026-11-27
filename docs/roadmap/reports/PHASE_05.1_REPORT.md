# Relatório da etapa 05.1 — Metas diárias

- **Data:** 2026-11-27
- **Estado:** `Concluída` em 2026-11-27, aprovada pelo responsável ("Aprovo e abra o PR"). Os seis critérios estão comprovados, incluindo o `AC-05.1-06`, acrescentado por você em 2026-11-27. O achado importante da ordem dos eventos de refeição foi tratado pela opção (b), que você escolheu (seção 6.1). Nenhum achado crítico ou importante de revisão está em aberto. As duas escolhas da seção 6.2 foram confirmadas por você ("concordo", 2026-11-27).
- **Branch:** `phase/05.1-daily-goals`, 26 commits sobre `main` `94f08c4`, mais o deste relatório, sem push.
- **Plano:** [2026-11-17-daily-goals.md](../../superpowers/plans/2026-11-17-daily-goals.md). **Design:** [2026-11-17-daily-goals-design.md](../../superpowers/specs/2026-11-17-daily-goals-design.md).

## 1. Resumo

A pessoa cria metas diárias de hábito de uma lista fechada, marca hoje ou ontem com um toque, pausa, retoma, encerra e apaga, e consulta os dias cumpridos. A meta de refeições fecha sozinha com a primeira refeição confirmada do dia.

- **Contexto `Goals`** (`apps/api/app/domains/goals`), com `Goals::Api` como única entrada:
  - Tabelas `goals` e `goal_check_ins`, com as regras no banco: CHECK de tipo, cadência, alvo e estado, índices únicos parciais e FK composta que amarra o dono do check-in ao dono da meta.
  - Cinco tipos: `log_meals`, `include_fruits_vegetables`, `drink_water`, `sleep_routine` e `planned_workout`. Calorias, déficit, peso e compensação são recusados pela API (`422 unsupported_goal_type`) e pelo banco.
  - O estado do dia não é gravado. Ele sai dos check-ins mais a regra versionada (`daily_any_v1`).
  - A janela de hoje e ontem usa o fuso da pessoa, e UTC enquanto o perfil está pendente. Datas antes do início da meta são recusadas.
  - Travas por meta, check-in idempotente e eventos `goal.created`, `goal.completed`, `goal.uncompleted` e `goal.deleted` pela outbox, na mesma transação.
  - Consumidores de `food_entry.confirmed` e `food_entry.deleted`, que aceitam os dois eventos de uma refeição em qualquer ordem: a exclusão deixa um marcador (`goal_removed_food_entries`, 30 dias) e os dois tomam a mesma trava por pessoa (`Goals::MealEventLock`).
  - Histórico só com dias cumpridos, por cursor, com o mesmo número de consultas para qualquer volume.
  - Exportação e exclusão de conta alcançam as tabelas novas.
- **API e contrato:** nove rotas (`goal_types`, lista, criar, ler uma, mudar estado, apagar, marcar, desmarcar e histórico), todas com `health_data`, exceto apagar a meta. Meta de outra pessoa responde 404.
- **App móvel:** telas Metas do dia (seletor Hoje/Ontem), Nova meta, Detalhe e Histórico. O link "Metas" fica na tela da câmera.

## 2. Validação

Executado em 2026-11-27 sobre o código final (`4c3732a`; o commit deste relatório só muda documentos). O resumo de cada rodada está em [verification-2026-11-27.txt](evidence/phase-05.1/verification-2026-11-27.txt), seção "Rodada depois da opção (b)".

| Comando | Código | Resultado |
|---|---|---|
| `RAILS_ENV=test bin/rails db:schema:load` | 0 | Banco de teste recarregado do `schema.rb` |
| `bundle exec rspec` | 0 | 1395 exemplos, 0 falhas |
| `bundle exec rubocop` | 0 | Sem ofensas |
| `bundle exec brakeman -q --no-pager -w2` | 0 | Sem avisos |
| `bundle exec bundle-audit check --update` | 0 | Sem vulnerabilidades |
| `npm run check -w @app/contracts` | 0 | Contrato e tipos gerados em dia |
| `npm audit --json` julgado por `scripts/check_npm_audit.py` | 0 | Nenhum alerta alto ou crítico (31 moderados) e nenhuma exceção vigente: a do GHSA-fc5q-39xc-vjpf saiu no PR #22 |
| `bash scripts/test-check-npm-audit.sh` | 0 | Verificador da auditoria testado |
| Web: `typecheck`, `lint`, `test`, `build` | 0 | 67 testes |
| Mobile: `typecheck`, `lint`, `test` | 0 | 28 suítes, 231 testes |
| `python3 scripts/check_language.py` e `bash scripts/test-check-language.sh` | 0 | `features/goals` incluída na verificação |
| `bash scripts/verify-harness.sh` e `bash scripts/test-verify-harness.sh` | 0 | Harness aprovado; 93 testes, 0 falhas |
| Gitleaks 8.30.1, `git --redact` (binário do CI, checksum conferido) | 0 | Sem vazamentos |
| `food_entry_ordering_concurrency_spec.rb`, 20 vezes | 0 | 20 de 20 verdes. Com todas as travas dos consumidores removidas de propósito, os 3 exemplos falharam em 5 de 5 rodadas |

## 3. Critérios

| Critério | Evidência | Situação |
|---|---|---|
| `AC-05.1-01` criar, editar e pausar a partir dos tipos permitidos | `spec/requests/goals_spec.rb`, `spec/domains/goals/manage_goals_spec.rb`, testes de `newGoal`, `detail` e `routes`; **demonstração real** no emulador Android com Expo Go contra a API local, capturas `mobile-01` a `mobile-27` | Comprovado |
| `AC-05.1-02` fuso, meia-noite e um check-in por dia | `spec/domains/goals/local_day_spec.rb` (São Paulo às 02:59:59 e 03:00 UTC, Auckland, horário de verão em Nova York, Manaus, fuso desconhecido), `goal_check_ins_spec.rb` "near midnight in America/Sao_Paulo", `check_in_concurrency_spec.rb` (threads reais), índice único | Comprovado |
| `AC-05.1-03` reavaliar dá o mesmo resultado | `spec/domains/goals/evaluate_day_spec.rb` (tabela de casos e 200 rodadas aleatórias com semente fixa), `check_in_spec.rb` "re-evaluating a person's recorded days gives the same results" | Comprovado |
| `AC-05.1-04` histórico paginado e isolado | `list_and_history_spec.rb` (cursor sem lacunas nem repetições, contagem de consultas igual com 10 e 30 dias), `goal_history_spec.rb`, `isolation_spec.rb` (todas as rotas de metas) | Comprovado |
| `AC-05.1-05` tipos proibidos recusados pela API e pelo banco | `goals_spec.rb` (422 sem linha criada e sem ecoar o tipo), `schema_constraints_spec.rb` (sete tipos proibidos com `CheckViolation`), `spec/contract/no_calorie_goal_spec.rb` | Comprovado |
| `AC-05.1-06` refeição apagada não deixa check-in, em qualquer ordem de entrega | `food_entry_ordering_concurrency_spec.rb` (duas conexões reais: exclusão durante a confirmação, confirmação durante a exclusão, meta criada no meio; 20 de 20 verdes, e 5 de 5 falhas com as travas removidas), `food_entry_ordering_spec.rb`, `meal_event_lock_spec.rb` | Comprovado. Ressalva: os specs chamam os consumidores direto, sem o `PublishJob` (seção 5) |

Na demonstração também foram conferidos:
- **Eventos no banco:** os oito eventos `goal.*` saíram com o payload do design 4.6, todos publicados e nenhum em dead letter ([goal-events-demo.txt](evidence/phase-05.1/goal-events-demo.txt)).
- **Log da API:** sem tipo de meta nem data de check-in. O `DELETE` aparece como `check_ins/[FILTERED]`.

## 4. Revisões

Cada tarefa teve revisão de especificação e qualidade. Antes do encerramento houve uma revisão final do branch inteiro (opus) e uma rodada de correção revisada.

| Revisão | Achados | Tratamento |
|---|---|---|
| Revisão final do branch | **F1:** data do check-in no log de requisição. **F2:** meta encerrada inalcançável para apagar. **F3:** pilha de telas duplicada e lista sem recarregar. Falta de spec de isolamento de `food_entry.deleted`. Ordem dos eventos de refeição | F1 a F3 e o spec foram corrigidos e re-revisados: `local_date` no filtro de log, `GET /goals/:id`, histórico com links, voltar à tela anterior e recarga no foco. A FK composta do dono também entrou. A ordem dos eventos foi para a seção 6.1 |
| `software-architect` (eventos) | **Importante:** ordem dos eventos de refeição, inclusive com dois workers sem falha nenhuma. Menores: catálogo listava como já consumidos eventos que Goals só consome na 05.2; regra de evolução dos payloads; trava depois da leitura | O importante está na seção 6.1. O catálogo foi corrigido e a regra "só acrescenta campos" registrada no `DOMAIN_MODEL.md`. A trava depende da decisão da seção 6.1 |
| `backend-reviewer` (regras, idempotência) | Nenhum crítico ou importante. Cinco menores: corrida rara na criação, encerrar de novo dá 409, N+1 limitado a 5 metas na lista, página de histórico que pode vir curta com regra futura, índice sem consulta que o justifique | Pendências (seção 6.3) |
| `security-reviewer` (segurança de produto) | **Importante:** o cursor do histórico (base64 de data e id da meta) ia ao log. Menores: id da meta em claro no caminho, linha de retenção ausente, conteúdo da exportação para a revisão jurídica | Cursor filtrado no log, com spec de ponta a ponta, re-revisado. Linha de retenção acrescentada. Os demais vão para a seção 6 |
| `frontend-mobile-reviewer` (tom e estados) | Nenhum crítico ou importante. Cinco menores: origem da refeição só aparece depois de um toque, "Feito" marcado distinguido só pelo preenchimento, recarga silenciosa sem aviso, aviso que persiste ao trocar de dia, estados do detalhe sem título | Pendências (seções 6.2 e 6.3) |
| `qa-reviewer` | Cinco critérios comprovados. Menores: F3 provado em teste com o roteador simulado, e a navegação real só na demonstração; verificação feita antes da limpeza do `schema.rb` | Registrado aqui e na seção 5. A verificação foi repetida no código final |

Segunda rodada, depois da opção (b) (`9589caf` a `4c3732a`):

| Revisão | Achados | Tratamento |
|---|---|---|
| `backend-reviewer` (trava consultiva) | Nenhum crítico. **Importante:** os specs de ordem usavam `sleep 0.5` e podiam passar sem a trava em máquina lenta. Menores: spec que podia travar sem timeout, `user_id` vazio virando chave global, ordem de travas sem registro, caminho do `PublishJob` fora do spec concorrente, limpeza sem `lock_timeout`, resíduo de marcador | O spec agora só libera a primeira transação quando a segunda está de fato esperando uma trava no banco, com timeouts e `join` garantido; provado com as travas removidas (5 de 5 falhas). `user_id` vazio recusado, com teste visto falhar antes. Ordem de travas no design e no `DOMAIN_MODEL.md`. O caminho do `PublishJob` vai para a seção 5 |
| `software-architect` | Nenhum crítico ou importante; o achado original está tratado e não precisa de ADR. Menores: texto da ordem de travas invertido, trava de linhas que sobrou da solução anterior, tabela ausente do design 4.2 e 4.9, relatório desatualizado | Texto corrigido e regra levada ao `DOMAIN_MODEL.md`. A trava que sobrou saiu (cada meta continua travada antes de mudar o dia), com os specs de metas e 20 rodadas de concorrência verdes. Design 4.2 e 4.9 atualizados. Este relatório |
| `security-reviewer` | Nenhum crítico. **Importante:** o marcador fora da exportação não estava nas pendências jurídicas; relatório desatualizado. Menores: marcador ausente do inventário, coleta para quem não tem meta, texto do resíduo após exclusão de conta mais cauteloso que o código, id da refeição no log do PostgreSQL quando a FK falha | Pendência jurídica 20 ampliada e linha própria no inventário de `PRIVACY_AND_LGPD.md`. Coleta ampla justificada no design 4.5 e levada à revisão jurídica. Texto do resíduo corrigido (a entrega descarta o evento). O log do PostgreSQL fica na seção 6.3 |
| `qa-reviewer` | Nenhum crítico. **Importante:** relatório e evidência anteriores ao código; matriz sem os caminhos novos; nenhum `AC-` cobre a ordem dos eventos. Menores: conta apagada sem conferir a ausência do marcador, retenção sem teste na borda dos 30 dias, spec da trava fraco, dois comentários desatualizados | Verificação refeita em `4c3732a`, matriz completada, AC proposto a você (seção 6.2). Specs novos: borda de 30 dias com relógio congelado, trava entre pessoas e fora de transação, ausência do marcador; cada um falhou com o defeito plantado. Comentários corrigidos |

## 5. Verificado e apenas criado

**Verificado:**
- Toda a suíte de cada aplicação e as auditorias da seção 2.
- O roteiro de demonstração inteiro no emulador:
  - cadastro com `health_data`;
  - criar duas metas;
  - marcar hoje e ontem e desmarcar;
  - refeição registrada à mão cumprindo a meta, e a exclusão da refeição desfazendo;
  - pausar, retomar, histórico, encerrar e apagar;
  - meta encerrada aberta pelo histórico e apagada;
  - voltar depois de criar, sem tela duplicada.
- Eventos no banco e o log da API do período, por busca nos arquivos.

- A ordem dos eventos de refeição, em testes com duas conexões reais: exclusão durante a confirmação, confirmação durante a exclusão, e meta criada no meio.

**Apenas criado ou com ressalva:**
- Não verificado: a ordem de travas completa da entrega real (`PublishJob` com `users FOR SHARE`) em concorrência. Os specs concorrentes chamam os consumidores direto, e a ordem é afirmada por leitura do código.
- Não verificado: o marcador remanescente depois da exclusão de conta. A regra de descarte da outbox deve impedir, por leitura do código, sem teste.
- Não verificado: a confirmação morta reprocessada depois de 30 dias, quando o marcador já saiu. O caso está descrito no `RUNBOOK_OUTBOX.md`.
- O spec de concorrência grava fora de transação e limpa com `TRUNCATE`, então exige banco de teste exclusivo, como já acontece no CI.
- A ordem dos eventos não tem demonstração no app. Só os testes a exercitam.
- A navegação real de "voltar e recarregar" está provada pela demonstração. O teste automatizado simula o roteador.
- A demonstração de "Ontem" recuou o início das duas metas da conta fictícia em um dia, no banco local. Uma meta criada hoje não aceita ontem, e a captura `mobile-06` mostra isso.
- O Expo Go é ambiente de testes. O build de distribuição fica para o M1.
- Sentry: só foi conferido por leitura (`ErrorScrubber` remove a URL), sem envio real. Segue a lacuna aceita do AC-01-07.

## 6. Pendências

### 6.1 Ordem dos eventos de refeição: tratada pela opção (b)

**A decisão.** Mensagem do responsável de 2026-11-27: "Implemente a opção (b) para a ordem dos eventos de refeição na 05.1."

**O problema.** Uma refeição confirmada e apagada em seguida gera `food_entry.confirmed` e `food_entry.deleted`, e a outbox não garante a ordem. Se a exclusão chegasse primeiro, o check-in da refeição ficava, e o dia aparecia "Feito" por uma refeição que não existe mais.

**O que entrou:**
- A exclusão grava um marcador `(user_id, food_entry_id)` em `goal_removed_food_entries` antes de remover o check-in. A confirmação que encontra o marcador não grava nada e não emite evento.
- Os dois consumidores tomam primeiro a mesma trava consultiva por pessoa (`Goals::MealEventLock`), e só ela os serializa. A opção descrevia uma trava nas linhas de `goals`, mas a revisão mostrou que ela não cobre a pessoa que cria a meta enquanto o evento está em trânsito.
- A exclusão para pessoa sem conta não faz nada. Antes ela mandava o evento para a fila de mortos.
- Os marcadores saem em 30 dias, o prazo dos eventos publicados da outbox, por um job diário, e saem também na exclusão de conta.

**Diferença do que a opção dizia.** A tabela da opção (b) falava em "com exportação". O marcador ficou **fora** da exportação, como o `source_ref` dos check-ins, por guardar só ids de uma refeição de outro contexto. Essa escolha foi do executor e precisa da sua confirmação (seção 6.2).

### 6.2 Decisões de produto pequenas

- **Exportação do marcador.** Ficou fora da exportação (seção 6.1), confirmado por você em 2026-11-27 ("concordo"). Segue na pendência jurídica 20 de `PRIVACY_AND_LGPD.md`, porque a revisão jurídica ainda confirma se atende ao art. 18, II.
- **Critério de aceite da ordem dos eventos.** Acrescentado como `AC-05.1-06` em `PHASE_05_GOALS.md` e na matriz (FR-GOALS-002), confirmado por você em 2026-11-27 ("concordo").
- **Origem da refeição antes do toque.** A meta de refeições cumprida por refeição aparece "Feito", com o mesmo visual do check-in manual. O texto "Cumprida pela refeição registrada." só aparece depois de desmarcar, como o design 4.10 descreve. Mostrar antes exige as fontes do dia em `GET /goals`, uma mudança de contrato.
- **Texto de `goal_not_active`.** Ficou como o plano manda. Para uma meta encerrada em outro aparelho, a mensagem fala em retomar, o que não é possível. Uma alternativa neutra seria "Esta meta não está ativa."
- **"Feito" marcado** se distingue só pelo preenchimento do botão. O leitor de tela recebe o estado. Um marcador visível, como o "[x]" do seletor Hoje/Ontem, ajudaria.

### 6.3 Menores registrados, sem bloquear

- **Backend:**
  - corrida de milissegundos na criação pode dar 500;
  - encerrar de novo uma meta encerrada responde 409, e não a meta;
  - a lista faz uma consulta por meta (no máximo 5);
  - a página do histórico pode vir curta com uma regra futura (05.2);
  - `index_goals_on_user_id_and_status` não tem consulta que o justifique;
  - o consumidor de exclusão de refeição não tem índice começando por `source_ref`.
- **App:**
  - a recarga silenciosa que falha não avisa;
  - o aviso persiste ao trocar Hoje/Ontem;
  - os estados de carregamento e erro do detalhe não têm título;
  - `dayText` é importado da feature de refeições.
- **Segurança:**
  - o id da meta (UUID) aparece em claro no caminho do log. Isso é aceitável se você tratar UUID como identificador não sensível;
  - quando a exclusão de refeição chega para uma pessoa sem conta, o INSERT do marcador falha pela FK, e o PostgreSQL pode registrar no log do servidor o `user_id` e o id da refeição. O caminho é quase inalcançável, porque `users` só tem exclusão lógica. A configuração de log da hospedagem fica para o M1.

### 6.4 Pendências que já existiam

- **Apagar cada meta depois de revogar `health_data`.** As rotas de leitura passam a 403, então o app não lista o que apagar. Restam a exportação ou a exclusão da conta. É o mesmo comportamento das refeições desde a Fase 03 (pendência jurídica 18). Vale tratar as duas áreas juntas.
- **Revisão jurídica:**
  - prazo de retenção de metas e check-ins, hoje "até apagar a meta ou a conta";
  - conteúdo da exportação.
- **`AC-M1-11`:** revisão dos textos e dos tipos de meta por profissional de saúde, antes do M1.

## 7. Decisões tomadas durante a execução

Decisões do executor, para você conferir. Cada uma traz o custo se estiver errada.

| Decisão | Custo se errada |
|---|---|
| A demonstração no emulador foi feita pelo executor, não por subagente | Nenhum |
| O design trocou `409 goal_already_exists` por `200` com a meta viva, e o plano já seguia isso | Um código de erro a mais |
| O plano dizia 02:05 UTC para 00:05 em São Paulo; o correto é 03:05 UTC, e os testes usam 03:05 | Nenhum |
| As fontes do dia aparecem em ordem alfabética (`food_entry`, `manual`) | Trocar uma ordenação |
| `PATCH` com estado inválido responde 422 antes de conferir o dono, sem revelar a meta | Trocar a ordem das checagens |
| Em "Ontem", o app não oferece "Feito" para meta criada hoje, comparando as datas vindas da API | Um botão escondido a mais |
| "Cumprida pela refeição registrada." aparece a partir das fontes da resposta do toque e do histórico | Acrescentar fontes ao contrato (seção 6.2) |
| Tela de histórico geral e detalhe de meta encerrada, porque o design promete que o histórico continua disponível | Uma tela a mais |
| A revisão final do branch veio antes de fechar a matriz e a verificação, que rodaram uma vez sobre o código final | Nenhum |
| A ordem dos eventos de refeição não foi corrigida sem você, porque toda correção muda o design | Nenhum: você escolheu a opção (b) |
| Na opção (b), a serialização passou à trava consultiva por pessoa, e a trava nas linhas de todas as metas `log_meals` saiu | Voltar a trava de linhas, se um caso novo aparecer |
| O marcador ficou fora da exportação (confirmado por você em 2026-11-27) | Um exportador a mais, se a revisão jurídica pedir |
| A exclusão de refeição de pessoa sem conta não faz nada, em vez de ir para a fila de mortos | Nenhum: não há meta a proteger |
| Entraram na correção final, por serem baratos: isolamento de `food_entry.deleted`, sem "Tentar de novo" após `goal_not_active`, rótulo "Feito: <tipo>", FK composta e linhas do `DOMAIN_MODEL.md` | Pequenos ajustes |
| Os textos de `goal_not_active` ficaram como o plano manda | Mensagem imprecisa para meta encerrada |
| A reformatação alheia do `schema.rb`, gerada pelo dump do banco local, foi revertida; o banco de teste foi recarregado dele e a suíte passou | Nenhum, provado pela verificação |
| Na correção de encerramento entraram o filtro de `cursor` no log, a linha de retenção e o catálogo de eventos; os menores ficaram como pendência | Pequenos ajustes depois |

## 8. Próximo passo

Para fechar a etapa: "Aprovo a etapa 05.1." Se quiser também o PR: "Pode fazer o push e abrir o PR."

A próxima linha do roadmap é o **M1** (beta fechado), que depende de 01, 02, 03 e 05.1. Para começar: "Vamos iniciar o M1."
