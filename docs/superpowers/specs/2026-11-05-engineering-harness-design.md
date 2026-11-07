# Design — Engineering Harness (Fase 00)

- **Data:** 2026-11-05
- **Estado:** aprovado pelo responsável pelo produto em 2026-11-05
- **Fonte principal:** Master Prompt "Fitness Companion" (colado na sessão de 2026-11-05) e conversa de brainstorming
- **Commits:** nenhum nesta sessão. O Master Prompt proíbe commits automáticos, o que prevalece sobre o padrão da skill `brainstorming`
- **Versionamento da fonte [E]:** o Master Prompt é salvo sem alterações em `docs/product/MASTER_PROMPT.md`, porque uma sessão nova não tem acesso à conversa original. Referências a "seção X do Master Prompt" apontam para esse arquivo.
- **Precedência [E]:** em caso de conflito, vale este design aprovado sobre o Master Prompt, somente nos desvios listados aqui: marco M1, divisão da Fase 05, ausência de hooks e arquivos acrescentados. Fora disso, vale o Master Prompt. Depois de escritos, os documentos do harness são a referência de trabalho, e mudar uma decisão exige ADR.

## 1. Intenção

Construir o sistema operacional de engenharia de um produto SaaS de bem-estar com gamificação. Um Claude Code em sessão nova, sem memória de sessões anteriores, deve conseguir ler o harness e saber o que é o produto, como ele é arquitetado, em que fase está, o que falta provar e como executar a próxima etapa.

**Por que importa aqui:** o produto tem um único desenvolvedor. O harness substitui a memória e a revisão que uma equipe daria. O sucesso do negócio, nas palavras do responsável, é ver pessoas usando o produto e encontrar uma forma eficaz de monetizar. Por isso o harness precisa encurtar o caminho até o uso real, em vez de acrescentar cerimônia.

## 2. Público do produto (decidido na conversa)

- Do iniciante que está começando a se cuidar à pessoa esportiva e competitiva.
- A experiência se adapta ao **nível de experiência** e ao **tipo de esporte**.
- Cada usuário vê a própria evolução.
- O primeiro entregável, na visão do responsável, é medir calorias e nutrientes dos alimentos por foto e acompanhar metas diárias.

## 3. Objetivos, não objetivos e antiobjetivos

**Objetivos**

1. Cobrir todos os itens da seção 14 do Master Prompt com documentos de conteúdo real.
2. Detalhar as Fases 00 a 09 com as 11 seções exigidas: objetivo, escopo, funcionalidades, dependências, arquivos e módulos esperados, critérios de aceite, testes, riscos, entregáveis, Definition of Done e estratégia de revisão.
3. Garantir rastreabilidade: requisito → ADR → fase → tarefa → implementação → teste → critério de aceite.
4. Tornar o protocolo de fase executável, com skills `phase-kickoff` e `phase-closeout`, status com evidência e script de verificação.

**Não objetivos desta sessão**

- Código de produto, migrations, endpoints, integração real com Strava ou IA, dependências de runtime e diretório `apps/`.
- Fazer commits.
- Escolher definitivamente provedor de IA, modelo de monetização, marca ou hospedagem.

**Antiobjetivos (falha mesmo que tudo "funcione")**

- Documentos que só preenchem a árvore, sem decisões ou critérios verificáveis.
- Decisão hipotética registrada como definitiva.
- Afirmação sobre API externa sem fonte e data.
- Cópia das skills do Superpowers para dentro do repositório.
- Processo pensado para equipe, que um desenvolvedor sozinho abandonaria em duas semanas.
- Produto que premie restrição alimentar, déficit calórico, excesso de exercício ou perda de peso.

## 4. Restrições factuais verificadas (consulta em 2026-11-05)

Estes fatos entram em `docs/architecture/EXTERNAL_SOURCES.md` com URL e data, e as decisões apontam para esse registro.

### Strava (API Agreement com vigência em 2026-06-01)

- **Dados de um usuário só podem ser exibidos a esse usuário:** *"Strava Data provided by a specific user can only be displayed or disclosed in your Developer Application to that user."* Dados de outros usuários não podem ser exibidos, mesmo públicos. Consequência: **um ranking não pode usar dados vindos do Strava**.
- *"You may not create applications that compete with or replicate Strava functionality."* O histórico de atividades deve ser um complemento à evolução do usuário, nunca uma réplica do feed.
- Ao encerrar o uso, todos os dados do Strava devem ser apagados, com certificação por escrito. Acesso não autorizado a token exige aviso em 24 horas.
- O texto lido **não menciona** IA ou machine learning. Decisão conservadora: não enviar dados do Strava a provedores de IA até uma reavaliação documentada.
- **Capacidade:** app novo aceita 1 atleta; com upgrade no painel, 10; acima disso, depende de revisão do Strava, sem garantia de aprovação. Criar um app exige assinatura do Strava.
- **Limites padrão:** 200 requisições/15 min e 2.000/dia no geral; 100/15 min e 1.000/dia em leitura.
- **OAuth:** access token dura 6 horas. O refresh token **rotaciona**, e o anterior é invalidado. Escopo mínimo proposto: `activity:read` (exigido pelos webhooks de atividade). `activity:read_all` só com justificativa, pois inclui atividades privadas e dados de zona de privacidade.
- **Desconexão:** `POST /oauth/revoke` existe desde 2026-06-01 e será o único endpoint a partir de 2027-06-01.
- **Webhooks:** uma assinatura por app. O callback responde em até 2 segundos, com até 3 tentativas de entrega. Os eventos cobrem criação, exclusão, mudança de título, tipo ou privacidade, e revogação pelo atleta.
- **Marca:** o nome do app não pode conter "Strava". Usar o botão "Connect with Strava", "Powered by Strava" e o link "View on Strava".

### Bases nutricionais

| Base | Situação | Uso em SaaS comercial |
|---|---|---|
| TBCA 7.3 (USP/FoRC) | Sem API ou download em massa encontrado. Texto: *"Para fins comerciais, é necessário contatar os coordenadores"*, *"Não é permitida a reprodução total ou parcial do material"*, *"Não é permitida a comercialização"* | **Bloqueada** até autorização por escrito (`tbca.contato@usp.br`) |
| USDA FoodData Central | API e download. CC0: *"No permission is needed for their use"*. Limite de 1.000 req/h | Permitido. Fraca em pratos brasileiros |
| Open Food Facts | API e dumps. ODbL, DbCL e CC BY-SA para imagens. Atribuição e compartilhamento pela mesma licença | Permitido com condições. O alcance da cláusula share-alike num SaaS é uma questão jurídica em aberto |
| TACO (NEPA/UNICAMP) | PDF obtido, mas não lido por falta de ferramenta local | **Licença não verificada.** Não usar até verificar |

### Versões

| Ferramenta | Atual oficial | Nesta máquina | Observação |
|---|---|---|---|
| Ruby | 4.0.9 (3.4 em manutenção normal) | 3.3.4 | 3.3 só recebe segurança, com fim esperado em 2027-03-31 |
| Rails | 8.1.4.1 | 8.1.4 | Exige Ruby ≥ 3.2. A compatibilidade com Ruby 4.0 é verificação da Fase 01 |
| Node | LTS 26.13 (22 e 24 também em LTS) | 22.18 | Expo SDK 58 exige ≥ 22.13; Vite 8 exige ≥ 20.19 ou ≥ 22.12 |
| React / Vite | 19.3 / 8.3.6 | n/a | |
| Expo | SDK 58 (React Native 0.88, React 19.3) | n/a | |
| PostgreSQL | 18.6 | 17.0 | 14 sai de suporte em 2026-11-12 |
| Sidekiq | 8.1.7 | n/a | Redis ≥ 7.0 ou Valkey ≥ 7.2 |
| Redis | **Não verificado** (página oficial retornou 404) | 7.4.1 | Versão e licença ficam para a Fase 01 |
| OpenAPI | 3.2.1 | n/a | O README do `rswag` declara compatibilidade com 3.0 e busca mantenedores. Não adotar sem avaliação |

### Provedores de IA

- **Anthropic:** JPEG, PNG, GIF e WebP; até 10 MB; base64, URL ou Files API. Saída estruturada por `output_config.format`, com JSON Schema sem `minimum`/`maximum`, logo os limites numéricos são validados na aplicação. O custo da imagem é `⌈w/28⌉ × ⌈h/28⌉` tokens. Preços por MTok: Haiku 5.5 US$ 0,10/0,50; Sonnet 5.5 US$ 2/10. A documentação diz que o conteúdo não é retido por padrão, salvo modelos cobertos (30 dias), e que dados retidos não treinam modelos sem permissão expressa; conteúdo sinalizado pode ser retido por até 2 anos. A Files API retém até exclusão explícita.
- **Google Gemini:** PNG, JPEG, WebP, HEIC e HEIF; requisição inline de até 20 MB. Gemini 3.8 Flash: US$ 0,75/3,75 até 2026-12-31. **O nível gratuito usa o conteúdo para melhorar produtos, então fica proibido**; o nível pago não usa.
- **OpenAI:** PNG, JPEG, WebP e GIF. **Preços e política de dados não verificados** (página retornou 403).
- **Ordem de grandeza (estimativa minha, a medir na Fase 03):** uma foto de 1568×1176 px dá cerca de 2.350 tokens de imagem. Com cerca de 800 tokens de saída, custa perto de US$ 0,001 no Haiku 5.5 e US$ 0,013 no Sonnet 5.5, sem contar o prompt.

### LGPD (Lei 13.709/2018)

- Dado referente à saúde é dado sensível (art. 5, II). O art. 11, §1, estende as regras ao tratamento que revele esse tipo de dado, o que torna prudente tratar fotos de refeições e atividades como sensíveis.
- O consentimento deve ser específico e destacado, com finalidades específicas (art. 11, I). Autorizações genéricas são nulas (art. 8, §4), e a revogação deve ser gratuita e facilitada (art. 8, §5).
- Adolescentes: tratamento no melhor interesse (art. 14). Portanto, MVP só para adultos.
- Transferência internacional, como enviar fotos a um provedor de IA nos EUA, precisa de base no art. 33, por exemplo cláusulas contratuais ou consentimento específico.
- Também obrigatórios: registro das operações (art. 37), encarregado com contato público (art. 41), comunicação de incidente (art. 48) e direitos do titular (art. 18).
- Os documentos do harness são orientação de engenharia, não parecer jurídico. A revisão por advogado é uma pendência antes de ter usuários reais.

## 5. Decisões de produto registradas

Marcadas como **[R]** (do responsável) ou **[E]** (escolha de engenharia, sujeita à revisão do responsável).

**Estado das decisões em ADR [E]:** a aprovação deste documento torna "Aceitas" as decisões desta seção e da seção 7 que não dependem de código para serem validadas, como princípios de XP, competição contra si mesmo, metas de hábito, M1 e idioma. Continuam "Propostas" as que dependem de código, de autorização externa ou de dados reais: versões, provedor de IA, base nutricional, autenticação, hospedagem, monetização e ranking. Critérios de aceite de fase podem depender de uma decisão "Proposta" apenas se a própria fase incluir o passo de decidi-la.

1. **[R]** Cada usuário vê a própria evolução.
2. **[R]** Ranking por esporte é uma ideia para aprofundar depois. **[E]** Fica fora das nove fases, como ADR em estado "Proposta", sem tabela nem tela. Pré-condições: não usar dados do Strava (seção 4), participação opcional, critérios que não premiem volume nem excesso, e reavaliação de privacidade. O motor de gamificação não precisa antecipar nada para isso.
3. **[E]** Perfil esportivo por esporte: a pessoa pode ser experiente em corrida e iniciante em musculação. Entra na Fase 02 como dado de perfil, é usado pela Fase 05 e pela Fase 06.
4. **[E]** XP premia cumprir o que faz sentido para o perfil, não volume absoluto, com teto diário e semanal para XP de atividade e dias de recuperação contando para a consistência.
5. **[E]** "Competição" no produto inicial é contra si mesmo: recordes pessoais, sequências e comparação com períodos anteriores.
6. **[R]** **Calorias aparecem como estimativa em faixa; metas diárias são de hábito, sem meta nem teto calórico.** Exemplos: registrar as refeições do dia, incluir vegetais, cumprir o treino planejado. Motivo: o Master Prompt proíbe mecanismos de restrição alimentar e pontuação baseada em calorias. O tema fica em ADR "Proposta", a reavaliar com dados do beta, e reabri-lo exige nova decisão do responsável.
7. **[R]** Monetização ainda sem modelo. **[E]** Registrada como ADR "Proposta" com alternativas e forma de validação, sem fase de cobrança. Limites que valem para qualquer modelo: não vender dados de saúde; não cobrar por exportação ou exclusão de dados; não colocar proteções de segurança atrás de pagamento.
8. **[E]** Custo de IA por análise e por usuário é medido desde a Fase 03, pois sustenta qualquer decisão de preço.
9. **[E]** Métricas de uso (ativação e retenção) entram com consentimento, antes do primeiro beta.
10. **[E]** Nome: "Fitness Companion" é provisório e o diretório se chama `nexora`. Nenhum dos dois é tratado como marca. Módulos e pacotes usam nomes neutros de domínio, para que trocar a marca não exija refatoração.

## 6. Marco de beta fechado (acréscimo ao roadmap)

As nove fases permanecem como no Master Prompt. **[E]** Acrescenta-se o marco **M1 — Beta fechado**, para colocar o primeiro entregável nas mãos de poucas pessoas (proposta: até 10) bem antes da Fase 09.

- **Conteúdo do M1:** Fases 01, 02 e 03 concluídas, mais a **etapa 1 da Fase 05** (metas diárias de hábito), com as telas móveis mínimas dessas fases.
- **Checklist mínimo do M1 (subconjunto da Fase 09):** revisão de privacidade, política publicada, consentimentos funcionando, exclusão de conta testada, backups testados, monitoramento de erros, limite de custo de IA por usuário e distribuição interna do app.
- **Ordem sugerida:** 01 → 02 → 03 → 05 etapa 1 → M1 → 04 → 05 etapa 2 → 06 → 07 → 08 → 09.
- A numeração não muda. A Fase 05 é dividida em etapas no seu próprio documento e não depende da Fase 04 para a etapa 1. Cada avanço continua dependendo da autorização do responsável.
- **Check-ins na etapa 1 [E]:** manuais. Metas como "cumprir o treino planejado" são marcadas pelo próprio usuário. A confirmação automática por atividades chega na etapa 2, depois da Fase 04.

**Dono de cada item do M1 [E]:**

| Item | Onde é feito |
|---|---|
| Consentimentos, exclusão de conta, política de retenção | Fase 02 |
| Monitoramento de erros | Fase 01 |
| Limite de custo de IA por usuário | Fase 03 |
| Hospedagem e deploy do beta, backups testados, distribuição interna do app, métricas de ativação e retenção com consentimento, política publicada, revisão de privacidade | Documento próprio `docs/roadmap/phases/MILESTONE_M1_CLOSED_BETA.md`, com as mesmas 11 seções de uma fase |

A Fase 09 reaproveita e reavalia esses itens para a escala de um lançamento, sem refazê-los. A decisão de hospedagem deixa de esperar a Fase 09 e é tomada no M1.

## 7. Arquitetura documentada no harness

Os documentos de arquitetura descrevem o que o Master Prompt pede nas seções 4 e 5. As escolhas centrais:

- **Monólito modular em Rails, monorepo** com `apps/api`, `apps/web`, `apps/mobile` e `packages/contracts` (ADR Aceita, por preferência declarada do responsável).
- **Domínios como namespaces**, sem Rails Engines. Limites verificados por testes de dependência. Ferramentas como Packwerk são avaliadas na Fase 01, sem assumir adoção.
- **12 bounded contexts** com responsabilidade, modelos, serviços, eventos, dependências permitidas e proibidas, conforme a seção 4.3 do Master Prompt.
- **Eventos internos com transactional outbox**, entrega pelo menos uma vez e consumidores idempotentes. Usada onde perder um evento gera dano (XP, conquistas, metas). Eventos de nome passado seguem o padrão `food_analysis.completed`.
- **Food AI em pipeline**, separando reconhecimento visual, estimativa de porção, consulta nutricional e cálculo. Interface de provedor, prompts versionados, saída validada por schema, dataset de avaliação, custo registrado por análise e proveniência dos dados. Estimativas guardadas como faixa com confiança, nunca como medição.
- **Bases nutricionais atrás de adaptador.** Proposta: USDA FDC como base legalmente liberada, catálogo próprio de pratos brasileiros compostos a partir de ingredientes, TBCA somente após autorização escrita. A Fase 03 não pode ser concluída sem a decisão de licenciamento registrada em ADR.
- **Gamificação independente**, consumindo apenas eventos. Livro-razão de XP só de inclusão, com chave de idempotência única por evento e regra. Regras versionadas. Critérios proibidos validados por teste.
- **Strava isolado no seu contexto**, com tokens cifrados, processamento assíncrono de webhook, resposta em até 2 segundos, sincronização inicial limitada pelos rate limits, reconciliação e exclusão ao desconectar.
- **Banco:** todas as tabelas da seção 5.3 do Master Prompt, mais `outbox_events`, `sport_profiles` e `ai_usage_records`, com chaves, índices, constraints, retenção e soft delete. Só documentadas: nenhuma migration nesta fase.

Decisões cuja validação depende de código ficam como "Proposta", com a forma de validar descrita.

## 8. Estrutura de arquivos

Segue a árvore da seção 3.2 do Master Prompt, com estes acréscimos justificados:

| Acréscimo | Motivo |
|---|---|
| `.claude/rules/database.md` | O Master Prompt pede regras de banco na seção 8 |
| `docs/roadmap/STATUS.md` | Controle de estado da seção 7.4 |
| `docs/roadmap/TRACEABILITY.md` | Matriz da seção 10 |
| `docs/roadmap/phases/MILESTONE_M1_CLOSED_BETA.md` | Marco de beta fechado (seção 6) |
| `docs/product/MASTER_PROMPT.md` | Fonte original disponível para sessões novas |
| `docs/architecture/EXTERNAL_SOURCES.md` | Fonte e data exigidas pela seção 11 |
| `docs/architecture/decisions/README.md` e `TEMPLATE.md` | Índice e formato das ADRs |
| `scripts/test-verify-harness.sh` | Prova que o verificador falha quando deve |
| `.gitignore` | Evita versionar segredos desde o primeiro commit |
| `docs/superpowers/specs` e `plans` | Local padrão das skills |

Os diretórios vazios atuais são preservados. `docker/` continua vazio até a Fase 01.

**Idioma [E]:** documentação em português do Brasil; identificadores, eventos e nomes de tabelas em inglês.

### Configuração do Claude Code

- **`CLAUDE.md`:** menos de 200 linhas, conforme a recomendação oficial. Funciona como mapa e contém as regras invioláveis, com ponteiros para os demais documentos, sem duplicá-los.
- **Rules:** `architecture`, `testing`, `security-and-privacy` e `product-safety` carregam sempre. `backend`, `database`, `frontend` e `mobile` usam `paths:` para `apps/api/**`, `apps/web/**` e `apps/mobile/**`, carregando sob demanda.
- **Agents:** revisores, sem `Edit` ou `Write`. `software-architect` só com `Read, Grep, Glob`. Os demais têm também `Bash`, para rodar testes e linters. O limite real fica documentado: `tools` não restringe comandos individuais de Bash, então a instrução do agente proíbe alterações e os `deny` do projeto cobrem o restante.
- **Skills:** `phase-kickoff` e `phase-closeout` orquestram e chamam as skills do Superpowers, sem substituí-las. Serão escritas com `superpowers:writing-skills`.
- **`.claude/settings.json`:** mantém `enabledPlugins`; `deny` para leitura de `.env` e de chaves privadas, além de `git push --force` e `git reset --hard`; `ask` para `git push` e `git commit`. O `deny` de `Read` não cobre `cat` via Bash, e isso fica documentado. Nenhum `allow` amplo.
- **Hooks:** nenhum nesta fase. O `verify-harness.sh` é executado no encerramento das fases e, a partir da Fase 01, no CI. Um hook acrescentaria atrito sem benefício enquanto só existe documentação.
- **Instalação do Superpowers:** habilitar o plugin no projeto não o baixa em outra máquina. O `README.md` e o `CLAUDE.md` indicam `claude plugin install superpowers@claude-plugins-official --scope project` e a versão validada (7.0.0).

## 9. Protocolo de execução e controle de fases

- **`PHASE_EXECUTION_PROTOCOL.md`** contém os passos das seções 7.1 a 7.3, referenciando as skills reais instaladas, incluindo `executing-plans` como alternativa a `subagent-driven-development`.
- **`STATUS.md`** tem duas partes: tabela com o estado atual de cada fase e registro de transições apenas com inclusões (data, de, para, evidência). As linhas são: Fases 00 a 09, `05.1`, `05.2` e `M1`. A linha `05` é apenas um resumo: fica "Concluída" quando `05.1` e `05.2` estiverem concluídas, e "Em desenvolvimento" entre as duas. Fora ela, só uma linha pode estar em "Em desenvolvimento" por vez, porque há um único desenvolvedor.
- **Estados permitidos:** Não iniciada, Em planejamento, Em desenvolvimento, Em revisão, Bloqueada, Concluída.
- **Regra:** concluir uma fase não inicia a seguinte. O Claude apresenta o relatório e aguarda autorização.
- **Fase 00:** só passa para "Concluída" após aprovação do responsável. Até lá, fica "Em revisão".
- **Identificadores:** `FR-<DOMÍNIO>-NNN` e `NFR-<TIPO>-NNN`, definidos uma única vez em `FUNCTIONAL_REQUIREMENTS.md`; as fases os referenciam.
- **Rastreabilidade na prática [E]:** `TRACEABILITY.md` tem uma linha por requisito com fase, ADR (quando houver decisão arquitetural), implementação, teste e critério de aceite. Fase e critério de aceite são preenchidos desde a Fase 00. Implementação e teste são preenchidos no encerramento de cada fase, não a cada tarefa; as tarefas ficam ligadas aos requisitos pelo plano da fase em `docs/superpowers/plans`. Assim a cadeia completa existe sem manutenção diária.

## 10. Verificação

`scripts/verify-harness.sh` em Bash com Python 3 da biblioteca padrão, sem dependências novas. Retorna código diferente de zero em qualquer falha crítica. Verifica:

1. Presença e conteúdo mínimo dos arquivos obrigatórios, incluindo os de todas as fases.
2. Frontmatter válido em agents, skills e rules com `paths`.
3. As 11 seções obrigatórias em cada documento de fase.
4. Links internos relativos em Markdown.
5. Rastreabilidade: todo requisito é coberto por uma fase e aparece em `TRACEABILITY.md`; toda referência em fase existe nos requisitos; e requisitos de fase "Concluída" têm implementação e teste preenchidos, salvo os da própria Fase 00, que não tem código.
6. ADRs com as seções exigidas e estado válido.
7. `STATUS.md` só com estados válidos, e transição para "Concluída" sempre com evidência.
8. Marcadores de texto inacabado (`TBD`, `TODO`, `FIXME`), exceto em modelos.
9. `CLAUDE.md` com menos de 200 linhas.
10. **Limite de escopo:** falha se `apps/`, `packages/`, `db/migrate` ou `docker-compose.yml` existirem enquanto a Fase 01 estiver "Não iniciada".

`scripts/test-verify-harness.sh` copia o harness para um diretório temporário, aplica um defeito por verificação e confirma a falha. Escrito antes do verificador, conforme `test-driven-development`.

**Markdown lint:** não adotado agora, pois exigiria dependência de Node sem benefício proporcional. Fica registrado para avaliação na Fase 01.

**Revisão final da documentação:** os subagents `software-architect`, `security-reviewer` e `qa-reviewer` revisam o conjunto antes do relatório, seguindo `requesting-code-review` e `receiving-code-review`, seguido de `verification-before-completion`.

## 11. O que fica a critério de quem executar

- Texto, profundidade e exemplos dos documentos, desde que cubram o exigido.
- Numeração final de requisitos e ADRs.
- Implementação interna do verificador.
- Modelo de cada subagent, salvo necessidade clara.
