# Relatório da etapa 05.1 — Metas diárias

- **Data:** 2026-11-27
- **Estado:** `Em desenvolvimento`. Tudo foi executado e os cinco critérios estão comprovados, mas há um achado importante de revisão sem tratamento: a ordem dos eventos de refeição (seção 6.1). A correção muda o design aprovado, então depende da sua decisão. Com ela, a etapa vai a `Em revisão`.
- **Branch:** `phase/05.1-daily-goals`, 21 commits sobre `main` `94f08c4`, sem push.
- **Plano:** [2026-11-17-daily-goals.md](../../superpowers/plans/2026-11-17-daily-goals.md). **Design:** [2026-11-17-daily-goals-design.md](../../superpowers/specs/2026-11-17-daily-goals-design.md).

## 1. Resumo

A pessoa cria metas diárias de hábito de uma lista fechada, marca hoje ou ontem com um toque, pausa, retoma, encerra e apaga, e consulta os dias cumpridos. A meta de refeições fecha sozinha com a primeira refeição confirmada do dia.

- **Contexto `Goals`** (`apps/api/app/domains/goals`), com `Goals::Api` como única entrada:
  - Tabelas `goals` e `goal_check_ins`, com as regras no banco: CHECK de tipo, cadência, alvo e estado, índices únicos parciais e FK composta que amarra o dono do check-in ao dono da meta.
  - Cinco tipos: `log_meals`, `include_fruits_vegetables`, `drink_water`, `sleep_routine` e `planned_workout`. Calorias, déficit, peso e compensação são recusados pela API (`422 unsupported_goal_type`) e pelo banco.
  - O estado do dia não é gravado. Ele sai dos check-ins mais a regra versionada (`daily_any_v1`).
  - A janela de hoje e ontem usa o fuso da pessoa, e UTC enquanto o perfil está pendente. Datas antes do início da meta são recusadas.
  - Travas por meta, check-in idempotente e eventos `goal.created`, `goal.completed`, `goal.uncompleted` e `goal.deleted` pela outbox, na mesma transação.
  - Consumidores de `food_entry.confirmed` e `food_entry.deleted`.
  - Histórico só com dias cumpridos, por cursor, com o mesmo número de consultas para qualquer volume.
  - Exportação e exclusão de conta alcançam as tabelas novas.
- **API e contrato:** nove rotas (`goal_types`, lista, criar, ler uma, mudar estado, apagar, marcar, desmarcar e histórico), todas com `health_data`, exceto apagar a meta. Meta de outra pessoa responde 404.
- **App móvel:** telas Metas do dia (seletor Hoje/Ontem), Nova meta, Detalhe e Histórico. O link "Metas" fica na tela da câmera.

## 2. Validação

Executado nesta sessão sobre o código final (`44a17b9`; `9255347` e os commits seguintes só mudam documentos). O resumo está em [verification-2026-11-27.txt](evidence/phase-05.1/verification-2026-11-27.txt).

| Comando | Código | Resultado |
|---|---|---|
| `RAILS_ENV=test bin/rails db:schema:load` | 0 | Banco de teste recarregado do `schema.rb` |
| `bundle exec rspec` | 0 | 1375 exemplos, 0 falhas |
| `bundle exec rubocop` | 0 | Sem ofensas |
| `bundle exec brakeman -q --no-pager -w2` | 0 | Sem avisos |
| `bundle exec bundle-audit check --update` | 0 | Sem vulnerabilidades |
| `npm run check -w @app/contracts` | 0 | Contrato e tipos gerados em dia |
| `npm audit --json` julgado por `scripts/check_npm_audit.py` | 0 | Só a exceção vigente GHSA-fc5q-39xc-vjpf (até 2026-12-17) |
| `bash scripts/test-check-npm-audit.sh` | 0 | Verificador da auditoria testado |
| Web: `typecheck`, `lint`, `test`, `build` | 0 | 67 testes |
| Mobile: `typecheck`, `lint`, `test` | 0 | 28 suítes, 231 testes |
| `python3 scripts/check_language.py` e `bash scripts/test-check-language.sh` | 0 | `features/goals` incluída na verificação |
| `bash scripts/verify-harness.sh` e `bash scripts/test-verify-harness.sh` | 0 | Harness aprovado; 93 testes, 0 falhas |
| Gitleaks 8.30.1, `git --redact` (binário do CI, checksum conferido) | 0 | Sem vazamentos |

## 3. Critérios

| Critério | Evidência | Situação |
|---|---|---|
| `AC-05.1-01` criar, editar e pausar a partir dos tipos permitidos | `spec/requests/goals_spec.rb`, `spec/domains/goals/manage_goals_spec.rb`, testes de `newGoal`, `detail` e `routes`; **demonstração real** no emulador Android com Expo Go contra a API local, capturas `mobile-01` a `mobile-27` | Comprovado |
| `AC-05.1-02` fuso, meia-noite e um check-in por dia | `spec/domains/goals/local_day_spec.rb` (São Paulo às 02:59:59 e 03:00 UTC, Auckland, horário de verão em Nova York, Manaus, fuso desconhecido), `goal_check_ins_spec.rb` "near midnight in America/Sao_Paulo", `check_in_concurrency_spec.rb` (threads reais), índice único | Comprovado |
| `AC-05.1-03` reavaliar dá o mesmo resultado | `spec/domains/goals/evaluate_day_spec.rb` (tabela de casos e 200 rodadas aleatórias com semente fixa), `check_in_spec.rb` "re-evaluating a person's recorded days gives the same results" | Comprovado |
| `AC-05.1-04` histórico paginado e isolado | `list_and_history_spec.rb` (cursor sem lacunas nem repetições, contagem de consultas igual com 10 e 30 dias), `goal_history_spec.rb`, `isolation_spec.rb` (todas as rotas de metas) | Comprovado |
| `AC-05.1-05` tipos proibidos recusados pela API e pelo banco | `goals_spec.rb` (422 sem linha criada e sem ecoar o tipo), `schema_constraints_spec.rb` (sete tipos proibidos com `CheckViolation`), `spec/contract/no_calorie_goal_spec.rb` | Comprovado |

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

**Apenas criado ou com ressalva:**
- A navegação real de "voltar e recarregar" está provada pela demonstração. O teste automatizado simula o roteador.
- A demonstração de "Ontem" recuou o início das duas metas da conta fictícia em um dia, no banco local. Uma meta criada hoje não aceita ontem, e a captura `mobile-06` mostra isso.
- O Expo Go é ambiente de testes. O build de distribuição fica para o M1.
- Sentry: só foi conferido por leitura (`ErrorScrubber` remove a URL), sem envio real. Segue a lacuna aceita do AC-01-07.

## 6. Pendências

### 6.1 Decisão necessária: ordem dos eventos de refeição (achado importante)

**O problema.** Uma refeição confirmada e apagada em seguida gera `food_entry.confirmed` e `food_entry.deleted`. A outbox não garante a ordem de entrega. Isso acontece quando há dois workers ao mesmo tempo, ou quando a confirmação é reprocessada depois de uma falha. Se a exclusão for processada antes de a confirmação gravar o check-in, o check-in fica. O dia aparece "Feito" por uma refeição que não existe mais, e a pessoa não consegue desfazer, porque desmarcar só remove o check-in manual. O `goal.completed` emitido fica sem o `goal.uncompleted` correspondente, e na Fase 06 isso daria XP indevido.

**As opções:**

| Opção | O que muda | Recomendação |
|---|---|---|
| (a) Goals consulta `Nutrition::Api` antes de gravar | Goals passa a depender de Nutrition, contra o design 4.5. Exige ADR. Ainda deixa uma janela entre a consulta e a gravação | Não recomendada |
| (b) Marcador de refeição apagada dentro de Goals | Tabela pequena só com ids, com exportação, exclusão e retenção. A exclusão trava as metas da pessoa, grava o marcador e remove o check-in; a confirmação trava a meta e consulta o marcador. Muda o design 4.5 e 4.6, sem ADR | **Recomendada** pela revisão de arquitetura |
| (c) Entrega em ordem por pessoa na outbox | Mexe no publicador de todos os domínios | Não recomendada |
| Aceitar o risco | Nada muda agora. Corrigir antes de a Fase 06 consumir `goal.completed` | Possível, com o risco registrado |

### 6.2 Decisões de produto pequenas

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
- **Segurança:** o id da meta (UUID) aparece em claro no caminho do log. Isso é aceitável se você tratar UUID como identificador não sensível.

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
| A ordem dos eventos de refeição não foi corrigida sem você, porque toda correção muda o design | O risco da seção 6.1 até a decisão |
| Entraram na correção final, por serem baratos: isolamento de `food_entry.deleted`, sem "Tentar de novo" após `goal_not_active`, rótulo "Feito: <tipo>", FK composta e linhas do `DOMAIN_MODEL.md` | Pequenos ajustes |
| Os textos de `goal_not_active` ficaram como o plano manda | Mensagem imprecisa para meta encerrada |
| A reformatação alheia do `schema.rb`, gerada pelo dump do banco local, foi revertida; o banco de teste foi recarregado dele e a suíte passou | Nenhum, provado pela verificação |
| Na correção de encerramento entraram o filtro de `cursor` no log, a linha de retenção e o catálogo de eventos; os menores ficaram como pendência | Pequenos ajustes depois |

## 8. Próximo passo

Escolha uma das duas frases sobre a ordem dos eventos:

- "Implemente a opção (b) para a ordem dos eventos de refeição na 05.1." Atualizo o design, implemento com TDD e teste de concorrência, reviso e trago o relatório de novo.
- "Aceito o risco da ordem dos eventos de refeição, com correção antes da Fase 06." Registro a aceitação e passo a etapa a `Em revisão`.

Depois, para fechar a etapa: "Aprovo a etapa 05.1." Se quiser também o PR: "Pode fazer o push e abrir o PR."

A próxima linha do roadmap é o **M1** (beta fechado), que depende de 01, 02, 03 e 05.1. Para começar: "Vamos iniciar o M1."
