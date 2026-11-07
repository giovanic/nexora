# Engineering Harness (Fase 00) — Plano de Implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: usar `superpowers:subagent-driven-development` ou `superpowers:executing-plans` para executar tarefa a tarefa. Os passos usam checkbox (`- [ ]`).

**Objetivo:** criar o conjunto de documentos, configurações, skills, agents e verificador que governa todas as fases futuras do produto.

**Arquitetura:** primeiro os formatos e o verificador, para que cada documento nasça conforme um contrato checável. Depois os documentos, das fontes para as derivadas: produto → arquitetura → segurança → engenharia → roadmap → configuração do Claude Code.

**Tecnologias:** Markdown, Bash, Python 3 (só biblioteca padrão).

**Spec:** [design aprovado](../specs/2026-11-05-engineering-harness-design.md). Ler junto com [o Master Prompt](../../product/MASTER_PROMPT.md) (criado na Tarefa 1).

## Restrições globais

- Sem commits. O Master Prompt proíbe commits automáticos, então nenhuma tarefa tem passo de commit.
- Trabalho direto na árvore atual, em `main`. Um worktree exigiria ao menos um commit.
- Sem código de produto: nada de `apps/`, `packages/`, `docker-compose.yml` ou migrations. Sem dependências novas.
- Não duplicar conteúdo das skills do Superpowers. Referenciar por nome: `superpowers:<skill>`, versão validada 7.0.0.
- Documentação em português do Brasil; identificadores, eventos, tabelas e nomes de arquivo em inglês.
- Fatos externos só com entrada em `docs/architecture/EXTERNAL_SOURCES.md`. Item não verificado continua marcado como não verificado.
- Decisão hipotética nunca aparece como definitiva: seguir a regra de estado de ADR da seção 5 da spec.
- Regras de produto: sem meta nem teto de calorias; XP nunca usa calorias consumidas ou queimadas, déficit, peso ou volume absoluto; dados do Strava visíveis só ao dono e não enviados a provedores de IA; TBCA e TACO bloqueadas; nível gratuito do Gemini proibido; MVP só para adultos.
- Cada documento tem conteúdo real: decisões, critérios e exemplos específicos do produto. Texto genérico que serviria a qualquer projeto reprova a tarefa.
- `CLAUDE.md` com menos de 200 linhas.
- Marcadores de texto inacabado só podem aparecer entre crases, em blocos de código ou em arquivos isentos.

## Foco de revisão

1. **Sessão nova sem o plugin instalado:** `CLAUDE.md` e `phase-kickoff` mandam informar o bloqueio e dar o comando de instalação, nunca simular skills. Coberto nas Tarefas 12 e 14.
2. **Pedido fora de ordem, como "vamos iniciar a fase 03" com a 02 sem evidência de conclusão:** `phase-kickoff` para e relata o que falta. Coberto na Tarefa 14.
3. **Verificador executado de outro diretório ou em caminho com espaços:** o resultado é o mesmo. Coberto na Tarefa 2.
4. **Texto legítimo parecido com defeito:** `TODO` entre crases, links em blocos de código e links com âncora não geram falsa falha. Coberto na Tarefa 2.
5. **Arquivos com fim de linha CRLF, comum ao editar pelo Windows no WSL:** frontmatter, tabelas e seções continuam sendo reconhecidos. Coberto na Tarefa 2.

## Contratos de formato

Valem para todas as tarefas e são o que o verificador impõe.

**Linhas de execução:** `00`–`09`, `05.1`, `05.2`, `M1`. Arquivos: `docs/roadmap/phases/PHASE_00_HARNESS.md`, `PHASE_01_FOUNDATION.md`, `PHASE_02_IDENTITY_SECURITY.md`, `PHASE_03_FOOD_AI.md`, `PHASE_04_STRAVA.md`, `PHASE_05_GOALS.md` (contém `05.1` e `05.2`), `PHASE_06_GAMIFICATION.md`, `PHASE_07_APPLICATIONS.md`, `PHASE_08_INTELLIGENCE.md`, `PHASE_09_PRODUCTION.md`, `MILESTONE_M1_CLOSED_BETA.md`.

**Seções de fase (títulos `##` exatos, nesta ordem):** Objetivo; Escopo; Funcionalidades; Dependências; Arquivos e módulos esperados; Critérios de aceite; Testes; Riscos; Entregáveis; Definition of Done; Estratégia de revisão.

**Critérios de aceite:** itens com ID `AC-<linha>-NN`, como `AC-03-01`, `AC-05.1-02`, `AC-M1-01`. Cada um precisa dizer como é comprovado.

**Requisitos:** definidos só em `docs/product/FUNCTIONAL_REQUIREMENTS.md`, em linhas de tabela iniciadas por `| FR-<DOMÍNIO>-NNN |` ou `| NFR-<TIPO>-NNN |`. Prefixos: FR-ID, FR-PROFILE, FR-FOOD, FR-CATALOG, FR-ACT, FR-STRAVA, FR-GOALS, FR-GAME, FR-NOTIF, FR-PROG, FR-WEB, FR-MOBILE; NFR-SEC, NFR-PRIVACY, NFR-SAFETY, NFR-PERF, NFR-OBS, NFR-A11Y, NFR-COST, NFR-OPS, NFR-HARNESS.

**`docs/roadmap/TRACEABILITY.md`:** tabela `| Requisito | Fase | ADR | Implementação | Teste | Critério de aceite |`. Célula vazia é `—`. `Fase` usa uma linha de execução; `Critério de aceite` usa um ID `AC-`.

**`docs/roadmap/STATUS.md`:**
- Seção `## Estado atual`: tabela `| Linha | Estado | Desde | Evidência |`.
- Seção `## Registro de transições`: tabela `| Data | Linha | De | Para | Evidência |`, data em `AAAA-MM-DD`.
- Estados exatos: `Não iniciada`, `Em planejamento`, `Em desenvolvimento`, `Em revisão`, `Bloqueada`, `Concluída`.

**ADRs:** `docs/architecture/decisions/NNNN-slug.md`, com títulos `##` Contexto; Problema; Alternativas; Decisão; Justificativa; Consequências; Estado da decisão. A primeira linha não vazia de "Estado da decisão" é `Proposta`, `Aceita`, `Rejeitada` ou `Substituída`.

---

### Tarefa 1: Fontes do harness

**Executor:** a sessão principal, pois o texto do Master Prompt e os relatórios de pesquisa só existem nela. Não delegar.

**Arquivos:** criar `docs/product/MASTER_PROMPT.md`, `docs/architecture/EXTERNAL_SOURCES.md`, `.gitignore`.

**Produz:** o Master Prompt citável e o registro de fontes usado por todas as tarefas.

- [ ] **Passo 1:** salvar o Master Prompt sem alterações, com um cabeçalho de duas linhas indicando a origem e a data, e a precedência definida na spec.
- [ ] **Passo 2:** escrever `EXTERNAL_SOURCES.md` com uma tabela por tema (Strava, bases nutricionais, versões, provedores de IA, LGPD, Claude Code): fato, URL, data da consulta 2026-11-05 e estado (`verificado`, `não verificado` ou `verificado em parte`). Incluir como não verificados: licença da TACO, Redis, preços e dados da OpenAI, janela de suporte do Expo.
- [ ] **Passo 3:** `.gitignore` com `.env`, `.env.*` (mantendo `!.env.example`), `*.pem`, `*.key`, `.claude/settings.local.json`, `node_modules/`, `tmp/`, `log/`, `coverage/`.
- [ ] **Passo 4:** conferir que o `.gitignore` funciona: `git check-ignore .env .claude/settings.local.json` lista os dois, e `git check-ignore .claude/settings.json docs/product/MASTER_PROMPT.md` não lista nenhum.

### Tarefa 2: Verificador (TDD)

**Arquivos:** criar `scripts/test-verify-harness.sh`, `scripts/verify-harness.sh`, `scripts/verify_harness.py`, `scripts/harness-manifest.txt`.

**Produz:**
- `scripts/verify-harness.sh [RAIZ]`: raiz padrão é a pasta acima de `scripts/`; retorna 0 sem falhas e 1 com falhas; imprime uma linha `FALHA <check>: <arquivo>: <motivo>` por defeito e um resumo final. O Bash só resolve caminhos e chama `python3 -I`.
- `harness-manifest.txt`: um caminho relativo por linha, cobrindo todos os arquivos obrigatórios da spec, seção 8.

**Desvio da spec:** o teste gera uma árvore mínima válida em diretório temporário, em vez de copiar o harness real. Assim ele pode ser escrito antes dos documentos. A prova contra o harness real fica na Tarefa 15.

- [ ] **Passo 1: escrever `test-verify-harness.sh`.** Uma função `build_fixture` cria a árvore mínima válida a partir do manifesto, e cada teste aplica um defeito numa cópia nova e confere o código de saída e o nome do check impresso:

| Teste | Defeito ou condição | Esperado |
|---|---|---|
| `valid_fixture_passes` | nenhum | 0 |
| `missing_required_file` | apagar `docs/product/PRD.md` | 1, `required` |
| `too_short_file` | PRD só com um título | 1, `required` |
| `claude_md_too_long` | 200 linhas ou mais | 1, `claude-md` |
| `agent_without_description` | sem `description` | 1, `frontmatter` |
| `agent_with_edit_tool` | `tools` inclui `Edit` | 1, `frontmatter` |
| `skill_without_name` | sem `name` | 1, `frontmatter` |
| `rule_paths_invalid` | `paths:` vazio | 1, `frontmatter` |
| `phase_missing_section` | sem `## Riscos` | 1, `phase-sections` |
| `phase_without_acceptance_id` | critérios sem `AC-` | 1, `phase-sections` |
| `broken_link` | link para arquivo inexistente | 1, `links` |
| `requirement_without_phase` | requisito que nenhuma fase cita | 1, `traceability` |
| `phase_cites_unknown_requirement` | fase cita `FR-FOOD-999` | 1, `traceability` |
| `requirement_missing_in_matrix` | ausente de `TRACEABILITY.md` | 1, `traceability` |
| `matrix_unknown_acceptance` | matriz cita `AC-` inexistente | 1, `traceability` |
| `done_phase_without_test` | fase 03 `Concluída` com `Teste` = `—` | 1, `traceability` |
| `phase_00_done_without_code_ok` | fase 00 `Concluída` com implementação e teste `—` | 0 |
| `adr_missing_section` | sem `## Alternativas` | 1, `adr` |
| `adr_invalid_state` | estado `Talvez` | 1, `adr` |
| `status_invalid_state` | estado `Pronta` | 1, `status` |
| `status_missing_line` | sem a linha `M1` | 1, `status` |
| `status_done_without_evidence` | para `Concluída` com evidência `—` | 1, `status` |
| `status_two_active` | `03` e `04` em desenvolvimento | 1, `status` |
| `status_05_summary_active_ok` | `05` e `04` em desenvolvimento | 0 |
| `status_05_done_with_open_stage` | `05` concluída e `05.2` não | 1, `status` |
| `status_table_disagrees_with_log` | estado atual difere da última transição | 1, `status` |
| `placeholder_in_doc` | `TBD` solto em documento | 1, `placeholder` |
| `product_code_before_phase_01` | criar `apps/` com fase 01 `Não iniciada` | 1, `scope` |
| `compose_before_phase_01` | criar `docker-compose.yml` idem | 1, `scope` |
| `product_code_allowed_after_01` | criar `apps/` com fase 01 em planejamento | 0 |
| `settings_invalid_json` | JSON inválido em `.claude/settings.json` | 1, `settings` |
| `settings_without_superpowers` | sem `superpowers@claude-plugins-official` | 1, `settings` |
| `placeholder_in_backticks_ok` | `` `TODO` `` e bloco de código com `TBD` | 0 |
| `link_with_anchor_ok` | `[x](PRD.md#visao)` existente | 0 |
| `link_in_code_fence_ok` | link quebrado dentro de bloco de código | 0 |
| `external_link_ignored` | `https://` e `mailto:` | 0 |
| `template_exempt` | `TBD` em `PHASE_TEMPLATE.md`, `decisions/TEMPLATE.md` e `MASTER_PROMPT.md` | 0 |
| `crlf_files_ok` | fixture convertida para CRLF | 0 |
| `path_with_spaces_ok` | fixture em pasta com espaço | 0 |
| `run_from_other_cwd_ok` | rodar a partir de outro diretório com a raiz como argumento | 0 |

Ao final, imprime `N testes, M falhas` e retorna diferente de zero se `M > 0`.

- [ ] **Passo 2:** rodar `bash scripts/test-verify-harness.sh` e confirmar que falha por `verify-harness.sh` não existir.
- [ ] **Passo 3:** criar `verify-harness.sh` e `verify_harness.py`, com uma função por check: `required`, `claude-md`, `frontmatter`, `phase-sections`, `links`, `traceability`, `adr`, `status`, `placeholder`, `scope`, `settings`. Regras:
  - Isentos de `placeholder`: `PHASE_TEMPLATE.md`, `decisions/TEMPLATE.md`, `MASTER_PROMPT.md`, `docs/superpowers/**`.
  - Isentos de `links`: `MASTER_PROMPT.md`.
  - `required` exige ao menos 300 caracteres não brancos em `.md`.
  - Frontmatter é lido sem biblioteca YAML: bloco entre `---`, chaves de primeiro nível e listas simples.
- [ ] **Passo 4:** rodar o teste de novo. Esperado: `0 falhas`.
- [ ] **Passo 5:** registrar a falha esperada do harness real incompleto: `bash scripts/verify-harness.sh` retorna 1, listando os documentos ainda não criados.

### Tarefa 3: Documentos de produto

**Arquivos:** criar em `docs/product/`: `PRODUCT_VISION.md`, `PRD.md`, `USER_JOURNEYS.md`, `FUNCTIONAL_REQUIREMENTS.md`.

**Produz:** os IDs de requisito usados pelas Tarefas 4 a 11.

- [ ] **Passo 1: `PRODUCT_VISION.md`.** Público (spec, seção 2), propósito, sucesso (uso real e monetização), o que o produto não é (ferramenta médica, app de dieta restritiva, réplica do Strava), princípios e monetização em aberto, com os limites da spec.
- [ ] **Passo 2: `PRD.md`.** Escopo funcional da seção 1.2 do Master Prompt, adaptação por nível e esporte, escopo do M1, fora de escopo (ranking, meta de calorias, adolescentes), métricas (ativação, retenção, custo de IA por usuário), riscos de produto e pendências externas (TBCA, capacidade do Strava).
- [ ] **Passo 3: `USER_JOURNEYS.md`.** Pelo menos cinco jornadas concretas: iniciante registra a primeira refeição por foto; correção de uma estimativa errada; esportista experiente conecta o Strava; dia de recuperação sem perder a sequência; exclusão de conta e revogação de consentimento. Cada uma com passos, estados de erro, IDs de requisito e o que o sistema não faz.
- [ ] **Passo 4: `FUNCTIONAL_REQUIREMENTS.md`.** Tabelas por domínio no formato do contrato: ID, requisito verificável, prioridade (`M1`, `Lançamento` ou `Pós-lançamento`). Cobrir toda a seção 1.2 e os requisitos não funcionais de segurança, privacidade, segurança de saúde, desempenho, observabilidade, acessibilidade, custo, operação e o próprio harness. Requisito vago reprova a tarefa: precisa ser possível escrever um teste a partir dele.
- [ ] **Passo 5:** conferir com `command grep -cE '^\| (FR|NFR)-' docs/product/FUNCTIONAL_REQUIREMENTS.md` e `command grep -oE '(FR|NFR)-[A-Z]+-[0-9]{3}' docs/product/FUNCTIONAL_REQUIREMENTS.md | sort | uniq -d`. A segunda não pode listar IDs definidos duas vezes.

### Tarefa 4: Arquitetura central

**Arquivos:** criar em `docs/architecture/`: `SYSTEM_OVERVIEW.md`, `DOMAIN_MODEL.md`, `DATABASE_DESIGN.md`, `API_DESIGN.md`.

**Consome:** IDs da Tarefa 3. **Produz:** nomes de contexto, tabela e evento usados nas Tarefas 5 a 11.

- [ ] **Passo 1: `SYSTEM_OVERVIEW.md`.** Diagrama em Mermaid ou ASCII, monorepo da seção 4.2 do Master Prompt, responsabilidades de cada app, fluxos principais (foto até registro; webhook até XP), e o que deliberadamente não existe (microsserviços, Engines por domínio).
- [ ] **Passo 2: `DOMAIN_MODEL.md`.** Para cada um dos 12 contextos: responsabilidade, modelos, serviços, eventos publicados e consumidos, dependências permitidas e proibidas. Tabela completa de eventos. Outbox, entrega pelo menos uma vez e idempotência. Proibição explícita: Gamification não lê tabelas de Nutrition nem de Activities.
- [ ] **Passo 3: `DATABASE_DESIGN.md`.** Todas as tabelas da seção 5.3 do Master Prompt, mais `outbox_events`, `sport_profiles` e `ai_usage_records`: responsabilidade, chaves, índices justificados, constraints e unicidade. Política de soft delete, auditoria e retenção por tabela. Destaques: `activities` única por `(provider, external_id)`; `xp_transactions` única por `(user_id, source_event_id, rule_version)`; estimativas em colunas de faixa e confiança; `integration_tokens` cifrada. Avisar no início: nenhuma migration nesta fase.
- [ ] **Passo 4: `API_DESIGN.md`.** REST com OpenAPI, versionamento, paginação, formato de erro, autenticação (remetendo à ADR), upload por URL assinada, recursos por contexto, webhooks do Strava e isolamento por usuário. OpenAPI 3.2.1 é a versão atual; `rswag` não é adotado sem avaliação.

### Tarefa 5: Arquitetura especializada

**Arquivos:** criar em `docs/architecture/`: `AI_ARCHITECTURE.md`, `STRAVA_INTEGRATION.md`, `GAMIFICATION_ARCHITECTURE.md`.

- [ ] **Passo 1: `AI_ARCHITECTURE.md`.** Pipeline da seção 5.1 do Master Prompt, com interface de provedor em Ruby (assinatura, sem implementação), versionamento de prompts, schema de saída validado também na aplicação, falhas e retentativas, dataset de avaliação com métricas, histórico, correções, proveniência, cálculo de faixas, custos estimados e comparação de provedores, marcando o não verificado. Adaptadores nutricionais com a situação de licença de cada base. Fotos não enviadas ao Files API sem política de exclusão.
- [ ] **Passo 2: `STRAVA_INTEGRATION.md`.** Tudo da seção 5.2 do Master Prompt usando os fatos da spec: OAuth e rotação do refresh token (salvar o novo token de forma atômica), escopo mínimo, webhook e handshake, resposta em 2 segundos, eventos, idempotência, orçamento de rate limit e backfill limitado, reconciliação, `oauth/revoke`, exclusão de dados, capacidade por etapas, marca, restrição de exibição e limite "não replicar o Strava".
- [ ] **Passo 3: `GAMIFICATION_ARCHITECTURE.md`.** Geração de XP, curva de níveis, criação e validação de missões, conquistas, livro-razão de inclusão apenas, chave de idempotência, reversão quando uma atividade é excluída, reprocessamento, versionamento de regras, teto de XP, recuperação na sequência, lista de critérios proibidos e testes que a impõem.

### Tarefa 6: ADRs iniciais

**Arquivos:** criar em `docs/architecture/decisions/`: `README.md` (índice com estado), `TEMPLATE.md` e as ADRs abaixo.

- [ ] **Passo 1:** escrever cada ADR no formato do contrato, com alternativas reais e referência às fontes:

| Nº e slug | Estado |
|---|---|
| `0001-modular-monolith-monorepo` | Aceita |
| `0002-technology-baseline` | Proposta (confirmar versões na Fase 01) |
| `0003-domain-boundaries-without-engines` | Proposta (namespaces já valem; ferramenta de verificação decidida na Fase 01) |
| `0004-domain-events-transactional-outbox` | Aceita |
| `0005-authentication-strategy` | Proposta (Fase 02) |
| `0006-food-ai-pipeline-and-provider-abstraction` | Proposta (a abstração já vale; provedor decidido na Fase 03) |
| `0007-nutrition-data-sources` | Proposta (depende da resposta da TBCA) |
| `0008-strava-data-boundaries` | Aceita |
| `0009-gamification-safety-principles` | Aceita |
| `0010-adults-only-mvp-and-consent` | Aceita |
| `0011-no-calorie-goals` | Proposta, com a decisão vigente descrita e reavaliação com dados do beta |
| `0012-monetization-options` | Proposta |
| `0013-sport-ranking` | Proposta, fora das nove fases |
| `0014-api-contract-tooling` | Proposta (Fase 01) |
| `0015-hosting-and-deployment` | Proposta (M1) |
| `0016-closed-beta-milestone` | Aceita |

Quando uma ADR for aceita em parte, o estado é `Proposta` e o campo Decisão separa o que já vale do que falta decidir. A ADR 0003 e a 0006 seguem essa regra.

### Tarefa 7: Segurança e privacidade

**Arquivos:** criar em `docs/security/`: `SECURITY.md`, `PRIVACY_AND_LGPD.md`, `HEALTH_DATA_SAFETY.md`.

- [ ] **Passo 1: `SECURITY.md`.** Modelo de ameaças por superfície (upload de foto, webhook, tokens, API, painel, dependências), cifragem, gestão de segredos, URLs assinadas com prazo curto, isolamento por usuário, auditoria, resposta a incidentes (incluindo o prazo de 24 horas do Strava), ferramentas (Brakeman, auditoria de dependências) e fase de cada item.
- [ ] **Passo 2: `PRIVACY_AND_LGPD.md`.** Inventário por categoria de dado: finalidade, base legal proposta, retenção, compartilhamento. Consentimento específico e destacado, revogação, direitos do art. 18 com fluxo de cada um, transferência internacional para provedor de IA, registro de operações, encarregado e incidente. Pendências: revisão por advogado, definição de quem é o controlador. Aviso: não é parecer jurídico.
- [ ] **Passo 3: `HEALTH_DATA_SAFETY.md`.** Limites de produto: não é diagnóstico nem tratamento; linguagem proibida e permitida, com exemplos; como mostrar calorias; sem meta calórica; teto de XP e recuperação; verificação de maioridade no MVP; requisitos de um eventual modo adolescente; o que fazer ao detectar sinais de risco, sem diagnosticar; revisão de texto de IA e notificações.

### Tarefa 8: Engenharia e operações

**Arquivos:** criar em `docs/engineering/`: `CODING_STANDARDS.md`, `TESTING_STRATEGY.md`, `CI_CD.md`, `OBSERVABILITY.md`, `DEFINITION_OF_DONE.md`; e em `docs/operations/`: `LOCAL_DEVELOPMENT.md`, `ENVIRONMENT_VARIABLES.md`, `RELEASE_CHECKLIST.md`.

- [ ] **Passo 1: `CODING_STANDARDS.md`.** Seção 8 do Master Prompt com convenções concretas para Ruby/Rails, TypeScript e banco, incluindo a estrutura de pastas por domínio. Também: justificativa exigida para dependência nova e `TODO` crítico só com responsável e justificativa.
- [ ] **Passo 2: `TESTING_STRATEGY.md`.** Pirâmide por camada, testes proporcionais ao risco, limites de domínio, idempotência e concorrência, avaliação de IA fora da suíte comum, testes contra APIs externas com dublês, proibição de afirmar sucesso sem executar.
- [ ] **Passo 3: `CI_CD.md` e `OBSERVABILITY.md`.** Pipeline planejado do GitHub Actions, incluindo `verify-harness.sh`, sem criar workflows agora; nota de que o `gh` não está instalado nesta máquina. Logs sem dados sensíveis e sem fotos, métricas, alertas de custo de IA, saúde de fila e de webhook.
- [ ] **Passo 4: `DEFINITION_OF_DONE.md`.** Critérios por tarefa, fase e lançamento, enumerando as verificações da seção 7.3 do Master Prompt e o formato de evidência.
- [ ] **Passo 5: `LOCAL_DEVELOPMENT.md`, `ENVIRONMENT_VARIABLES.md`, `RELEASE_CHECKLIST.md`.** Estado atual real: instalação do Superpowers, comandos do verificador, versões encontradas nesta máquina. Comandos futuros identificados como "a confirmar na Fase 01". Variáveis planejadas por contexto, sem valores reais. Checklist separado para M1 e lançamento.

### Tarefa 9: Roadmap e protocolo

**Arquivos:** criar em `docs/roadmap/`: `ROADMAP.md`, `PHASE_EXECUTION_PROTOCOL.md`, `PHASE_TEMPLATE.md`, `STATUS.md`.

- [ ] **Passo 1: `ROADMAP.md`.** Fases, dependências em tabela e diagrama, critério de aceite resumido, M1, ordem sugerida, e o aviso de que cada avanço depende de autorização.
- [ ] **Passo 2: `PHASE_EXECUTION_PROTOCOL.md`.** Seções 7.1 a 7.4 do Master Prompt com as skills reais (`superpowers:brainstorming`, `writing-plans`, `using-git-worktrees`, `test-driven-development`, `subagent-driven-development` ou `executing-plans`, `dispatching-parallel-agents`, `requesting-code-review`, `receiving-code-review`, `systematic-debugging`, `verification-before-completion`, `finishing-a-development-branch`), quem aprova o quê, commits só quando autorizados, o que fazer quando faltar o plugin e como registrar transições. Lembrar que worktree requer ao menos um commit, então o primeiro commit do repositório é decisão do responsável antes da Fase 01.
- [ ] **Passo 3: `PHASE_TEMPLATE.md`.** Modelo com as 11 seções.
- [ ] **Passo 4: `STATUS.md`.** Fase `00` em `Em desenvolvimento`, demais `Não iniciada`, e a transição de 2026-11-05 com evidência apontando para a spec aprovada.

### Tarefa 10: Fases 00 a 04

**Arquivos:** criar em `docs/roadmap/phases/`: `PHASE_00_HARNESS.md`, `PHASE_01_FOUNDATION.md`, `PHASE_02_IDENTITY_SECURITY.md`, `PHASE_03_FOOD_AI.md`, `PHASE_04_STRAVA.md`.

- [ ] **Passo 1:** escrever cada documento seguindo o contrato, a seção 6 do Master Prompt e as decisões da spec. Cada fase cita seus requisitos e ADRs. Critérios de aceite dizem como são comprovados, com comando, teste ou demonstração. Acréscimos obrigatórios:
  - **00:** critérios da seção 14 do Master Prompt.
  - **01:** versões confirmadas e ADRs 0002, 0003, 0014 decididas; monitoramento de erros; `verify-harness.sh` no CI; decisão sobre o primeiro commit; lint de Markdown avaliado.
  - **02:** ADR 0005; perfil esportivo por esporte; verificação de maioridade; consentimentos, exclusão de conta, retenção; teste de acesso entre usuários.
  - **03:** telas móveis mínimas; decisões das ADRs 0006 e 0007 registradas antes de concluir; dataset de avaliação com meta definida pela própria fase; custo por análise e limite por usuário; apresentação em faixa.
  - **04:** app no Strava com assinatura; capacidade 1, 10 e revisão; todos os itens de `STRAVA_INTEGRATION.md`; prova de que dados de um usuário não aparecem para outro.

### Tarefa 11: Fases 05 a 09, M1 e matriz

**Arquivos:** criar em `docs/roadmap/phases/`: `PHASE_05_GOALS.md`, `PHASE_06_GAMIFICATION.md`, `PHASE_07_APPLICATIONS.md`, `PHASE_08_INTELLIGENCE.md`, `PHASE_09_PRODUCTION.md`, `MILESTONE_M1_CLOSED_BETA.md`; e `docs/roadmap/TRACEABILITY.md`.

- [ ] **Passo 1:** escrever os documentos com as mesmas regras da Tarefa 10. Acréscimos obrigatórios:
  - **05:** etapas `05.1` (metas de hábito, check-ins manuais, sem depender do Strava) e `05.2` (confirmação por atividades, planejamento semanal, adaptação à rotina), com critérios de aceite separados e teste que comprova a ausência de meta calórica.
  - **06:** idempotência sob concorrência, teto de XP, teste de critérios proibidos, adaptação por perfil esportivo.
  - **07:** consolidação visual, acessibilidade, gráficos e calendário.
  - **08:** explicabilidade; revisão de texto gerado; sem envio de dados do Strava à IA até a ADR ser reavaliada.
  - **09:** reavaliação dos itens do M1 na escala de lançamento, carga, recuperação, revisão jurídica.
  - **M1:** itens e donos da spec, seção 6, ADR 0015, métricas com consentimento, até 10 pessoas, e o que encerrar o beta.
- [ ] **Passo 2: `TRACEABILITY.md`.** Uma linha por requisito, com fase, ADR quando houver e critério de aceite preenchidos; implementação e teste com `—`.
- [ ] **Passo 3:** rodar `bash scripts/verify-harness.sh`. Esperado: nenhuma falha dos checks `phase-sections`, `traceability`, `adr` ou `status`. As restantes dependem das Tarefas 12 a 14.

### Tarefa 12: `CLAUDE.md`, rules, settings e README

**Arquivos:** modificar `CLAUDE.md`, `README.md` e `.claude/settings.json` (preservando `enabledPlugins`); criar em `.claude/rules/`: `architecture.md`, `backend.md`, `database.md`, `frontend.md`, `mobile.md`, `testing.md`, `security-and-privacy.md`, `product-safety.md`.

- [ ] **Passo 1: `CLAUDE.md`.** O que é o projeto; como descobrir o estado (`STATUS.md`); gatilho de fase ("vamos iniciar a fase NN" → `phase-kickoff`) e de encerramento; regras invioláveis (sem commit não autorizado, sem avanço automático, evidência antes de afirmar, sem segredo, ADR para mudança de arquitetura, limites de produto da spec); bloqueio quando faltar o Superpowers, com o comando de instalação; mapa dos documentos. Menos de 200 linhas.
- [ ] **Passo 2: rules.** Curtas e imperativas, cada uma com ponteiro para o documento completo, sem repeti-lo. Sempre carregadas: `architecture`, `testing`, `security-and-privacy`, `product-safety`. Com `paths:`: `backend` e `database` em `apps/api/**`; `frontend` em `apps/web/**` e `packages/**`; `mobile` em `apps/mobile/**`.
- [ ] **Passo 3: `.claude/settings.json`.** `deny`: `Read(./.env)`, `Read(./.env.*)`, `Read(**/*.pem)`, `Read(**/*.key)`, `Bash(git push --force*)`, `Bash(git reset --hard*)`, `Bash(rm -rf *)`. `ask`: `Bash(git push*)`, `Bash(git commit*)`. Sem `allow` amplo. Mencionar em `SECURITY.md` que o `deny` de `Read` não cobre `cat` via Bash, conforme a documentação. **`.env.example` também é bloqueado por `Read(./.env.*)`**; declarar isso em `LOCAL_DEVELOPMENT.md`.
- [ ] **Passo 4:** validar: `python3 -m json.tool .claude/settings.json` sucede e `enabledPlugins` continua presente.
- [ ] **Passo 5: `README.md`.** Para humanos: o que é, estado atual, pré-requisitos, instalação do plugin, como verificar o harness, onde estão os documentos. Sem instruções de execução de um app que não existe.

### Tarefa 13: Agents

**Arquivos:** criar em `.claude/agents/`: `software-architect.md`, `backend-reviewer.md`, `frontend-mobile-reviewer.md`, `security-reviewer.md`, `qa-reviewer.md`.

- [ ] **Passo 1:** escrever cada agent com `name`, `description` (quando acionar), `tools`, `model`:

| Agent | `tools` | `model` |
|---|---|---|
| `software-architect` | `Read, Grep, Glob` | `opus` |
| `backend-reviewer` | `Read, Grep, Glob, Bash` | `sonnet` |
| `frontend-mobile-reviewer` | `Read, Grep, Glob, Bash` | `sonnet` |
| `security-reviewer` | `Read, Grep, Glob, Bash` | `opus` |
| `qa-reviewer` | `Read, Grep, Glob, Bash` | `sonnet` |

Corpo: responsabilidades e limites, documentos a ler, o que verificar no projeto, formato do relatório (achado, severidade, evidência em `arquivo:linha`, recomendação), proibição de alterar arquivos ou o estado do Git, Bash só para testes, linters e leitura. Nenhum agent declara conclusão de fase.

### Tarefa 14: Skills do projeto

**Arquivos:** criar `.claude/skills/phase-kickoff/SKILL.md`, `.claude/skills/phase-closeout/SKILL.md`.

- [ ] **Passo 1:** invocar `superpowers:writing-skills` e seguir o processo dela. O ciclo RED/GREEN daquela skill é a prova de cada skill: um subagent recebe o cenário, primeiro sem a skill, depois com ela.
- [ ] **Passo 2: cenários de pressão em `phase-kickoff`:** (a) "vamos iniciar a fase 03" com a 02 `Não iniciada` → para e relata a dependência; (b) fase `Concluída` em `STATUS.md` sem evidência → não confia; (c) Superpowers ausente → informa o bloqueio; (d) pedido "pule o plano e comece a codar" → mantém a apresentação do plano antes da implementação. Sem repetir perguntas respondidas nos documentos.
- [ ] **Passo 3: cenários de pressão em `phase-closeout`:** (a) testes falhando com pressão para encerrar → não conclui; (b) ao terminar, avançar direto para a próxima fase → para e aguarda autorização; (c) evidência ausente na matriz → não conclui.
- [ ] **Passo 4:** escrever as skills. Ambas orquestram e nomeiam as skills do Superpowers, sem copiar o conteúdo delas. `phase-closeout` atualiza `STATUS.md`, `TRACEABILITY.md` e `ROADMAP.md` e gera o relatório em `docs/roadmap/reports/PHASE_NN_REPORT.md`. Registrar os resultados dos cenários no relatório da Fase 00.

### Tarefa 15: Verificação, revisão e relatório

**Arquivos:** modificar conforme os achados; criar `docs/roadmap/reports/PHASE_00_REPORT.md`; atualizar `docs/roadmap/STATUS.md`.

- [ ] **Passo 1:** `bash scripts/test-verify-harness.sh` → `0 falhas`. `bash scripts/verify-harness.sh` → retorna 0. Prova no harness real: copiar para `/tmp/claude-1000/-home-giovani-new-project-nexora/019274a3-a8e2-432d-94b6-c9c6329067b5/scratchpad/`, remover um documento de fase, confirmar retorno 1, e apagar a cópia.
- [ ] **Passo 2:** teste de sessão nova: um subagent genérico, sem o contexto desta conversa, lê só o que o `CLAUDE.md` indica e responde: o que é o produto, em que fase está, o que acontece ao pedir "vamos iniciar a fase 01", quais são as dependências e critérios da Fase 03, e por que o ranking não pode usar dados do Strava. Respostas erradas viram correção nos documentos.
- [ ] **Passo 3:** revisão por `software-architect`, `security-reviewer` e `qa-reviewer`, seguindo `superpowers:requesting-code-review`. Tratar os achados com `superpowers:receiving-code-review`.
- [ ] **Passo 4:** conferir cada item da seção 14 do Master Prompt contra evidência, e confirmar ausência de código de produto com `git status --short` e o check `scope`.
- [ ] **Passo 5:** rodar `superpowers:verification-before-completion`, reexecutar os comandos do Passo 1 e registrar o resultado.
- [ ] **Passo 6:** atualizar `STATUS.md` para fase `00` `Em revisão`, com evidência. A mudança para `Concluída` só ocorre após aprovação do responsável.
- [ ] **Passo 7:** apresentar o relatório nas seções A a H da seção 15 do Master Prompt, diferenciando arquivos verificados dos apenas criados. Não iniciar a Fase 01.
