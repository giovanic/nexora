# Registro de fontes externas

Toda decisão que depende de informação externa aponta para este registro. Regra da seção 11 do [Master Prompt](../product/MASTER_PROMPT.md): fonte oficial, versão confirmada, data da consulta e nada inventado.

- **Consulta:** todas as entradas foram lidas em **2026-11-05**, salvo indicação.
- **Estados:** `verificado` (lido na fonte oficial), `verificado em parte` (lido em parte, com a lacuna descrita), `não verificado` (não usar como base de decisão sem nova consulta).
- **Validade:** versões, preços e termos mudam. Toda fase confere de novo as entradas de que depende, no início, e atualiza a data aqui.

## Strava

| Fato | Fonte | Estado |
|---|---|---|
| Autorização em `/oauth/authorize` (web) e `/oauth/mobile/authorize` (mobile); troca do código em `POST /oauth/token`; o código é de uso único e curta duração | https://developers.strava.com/docs/authentication/ | verificado |
| O atleta pode desmarcar escopos, então o `scope` retornado pode diferir do pedido | https://developers.strava.com/docs/authentication/ | verificado |
| Escopos: `read`, `read_all`, `profile:read_all`, `profile:write`, `activity:read`, `activity:read_all`, `activity:write`. `activity:read` é exigido para webhooks de atividade e cobre atividades visíveis a Everyone e Followers, sem dados de zona de privacidade | https://developers.strava.com/docs/authentication/ | verificado |
| Access token expira em 6 horas. Com mais de 1 hora restante, o refresh devolve o token atual | https://developers.strava.com/docs/authentication/ | verificado |
| Refresh token rotaciona: *"Once a new refresh token is returned, the older refresh token is invalidated immediately."* | https://developers.strava.com/docs/authentication/ | verificado |
| `POST /oauth/revoke` disponível desde 2026-06-01; será o único endpoint de desautorização a partir de 2027-06-01. Retorna 200 mesmo se o token não existir | https://developers.strava.com/docs/authentication/ | verificado |
| Uma assinatura de webhook por aplicação; gerenciada em `/api/v3/push_subscriptions` | https://developers.strava.com/docs/webhooks/ | verificado |
| Validação: `GET` com `hub.mode`, `hub.challenge`, `hub.verify_token`; responder em até 2 segundos com `{ "hub.challenge": "<valor>" }` | https://developers.strava.com/docs/webhooks/ | verificado |
| Eventos: `object_type` (`activity`, `athlete`), `object_id`, `aspect_type` (`create`, `update`, `delete`), `updates`, `owner_id`, `subscription_id`, `event_time`. Confirmar com 200 em até 2 segundos; até 3 tentativas | https://developers.strava.com/docs/webhooks/ | verificado |
| Revogação pelo atleta chega com `updates` contendo `"authorized": "false"`. A página não declara `object_type` e `aspect_type` desse evento | https://developers.strava.com/docs/webhooks/ | verificado em parte |
| Limites padrão: geral 200/15 min e 2.000/dia; leitura 100/15 min e 1.000/dia. Com upgrade: 400/15 min e 4.000/dia; leitura 200/15 min e 2.000/dia. Headers `X-RateLimit-*` e `X-ReadRateLimit-*`. Janelas em 0, 15, 30 e 45 min; dia reinicia à meia-noite UTC. Excesso retorna 429; sem `Retry-After` documentado | https://developers.strava.com/docs/rate-limits/ | verificado |
| API Agreement em vigor desde 2026-06-01: *"Strava Data provided by a specific user can only be displayed or disclosed in your Developer Application to that user."* Dados de outros usuários não podem ser exibidos, mesmo se públicos | https://www.strava.com/legal/api | verificado |
| *"You may not create applications that compete with or replicate Strava functionality."* | https://www.strava.com/legal/api | verificado |
| Ao encerrar, apagar todos os dados e certificar por escrito (4.4). Aviso em 24 horas ao descobrir acesso não autorizado a token (1.2). Sem prazo geral de retenção no texto lido | https://www.strava.com/legal/api | verificado |
| Acesso hoje sem custo, com direito de cobrança mediante aviso (3.2). O texto lido não traz proibição própria de uso comercial | https://www.strava.com/legal/api | verificado |
| O texto lido não menciona IA, machine learning nem cache | https://www.strava.com/legal/api | verificado em parte (ausência no texto obtido, não autorização) |
| App novo com capacidade de 1 atleta; 10 com upgrade no painel; acima disso exige revisão, sem garantia. Criar app exige assinatura do Strava | https://developers.strava.com/docs/getting-started/ e https://developers.strava.com/docs/rate-limits/ | verificado |
| Marca: nome do app não pode conter "Strava"; botão "Connect with Strava"; "Powered by Strava" ou "Compatible with Strava"; link com texto "View on Strava" | https://developers.strava.com/guidelines/ (revisão de 2025-09-29) | verificado |
| Redirect URI precisa estar no domínio de callback; `localhost` e `127.0.0.1` são aceitos | https://developers.strava.com/docs/authentication/ | verificado |
| `/oauth/revoke` usa autenticação básica com `client_id:client_secret` | https://developers.strava.com/docs/authentication/ | verificado |
| `callback_url` tem até 255 caracteres | https://developers.strava.com/docs/webhooks/ | verificado |
| Com `activity:read` apenas, mudar visibilidade de/para "Only You" chega como `delete` e `create` | https://developers.strava.com/docs/webhooks/ | verificado |
| Uma mesma gravação pode gerar vários eventos, de forma assíncrona | https://developers.strava.com/docs/webhooks/ | verificado |
| Violações de curto prazo contam também para o limite de longo prazo | https://developers.strava.com/docs/rate-limits/ | verificado |
| Um token de API por aplicação (1.1); violação pode levar à revogação do token (2.2) | https://www.strava.com/legal/api | verificado |
| Atribuição à Garmin fortemente recomendada na seção Get Activity | https://developers.strava.com/docs/reference/ | verificado em parte |
| Referência completa da API | https://developers.strava.com/docs/reference/ | verificado em parte (lido o início; reler na Fase 04) |

## Bases nutricionais

| Fato | Fonte | Estado |
|---|---|---|
| TBCA versão 7.3 (USP/FoRC, 2025). Sem API ou download em massa encontrado | https://www.tbca.net.br/ | verificado |
| TBCA: *"Para fins comerciais, é necessário contatar os coordenadores."*, *"Não é permitida a reprodução total ou parcial do material."*, *"Não é permitida a comercialização."*, *"Não é permitido a alteração total ou mesmo parcial do conteúdo."* Contato: `tbca.contato@usp.br` | https://www.tbca.net.br/ | verificado |
| TBCA em SaaS comercial: a página é ambígua e não define reprodução nem comercialização. Tratada como bloqueada até autorização por escrito | https://www.tbca.net.br/ | verificado (o texto é ambíguo; a interpretação é decisão de engenharia) |
| USDA FoodData Central: CC0, *"No permission is needed for their use"*; citação solicitada, não exigida. API com chave do data.gov e limite padrão de 1.000 requisições/hora por IP. Download em CSV e JSON | https://fdc.nal.usda.gov/ e https://fdc.nal.usda.gov/api-guide | verificado |
| Open Food Facts: banco sob ODbL, conteúdos sob DbCL, imagens sob CC BY-SA. Uso comercial permitido com atribuição e compartilhamento pela mesma licença em derivados. API em produção só com 1 chamada por leitura real de usuário; proibido raspar; dumps diários. *"must not be used for medical purposes"* | https://world.openfoodfacts.org/data e https://world.openfoodfacts.org/terms-of-use | verificado |
| Alcance da cláusula share-alike da ODbL num SaaS | https://world.openfoodfacts.org/data | não verificado (questão jurídica) |
| TACO (NEPA/UNICAMP): licença e condições de uso | https://nepa.unicamp.br/publicacoes/tabela-taco-pdf/ | não verificado (PDF obtido, não lido por falta de ferramenta local) |

## Versões

| Ferramenta | Fato | Fonte | Estado |
|---|---|---|---|
| Ruby | Estável 4.0.9. 4.0 e 3.4 em manutenção normal. 3.3 só segurança, fim esperado em 2027-03-31 | https://www.ruby-lang.org/en/downloads/ e https://www.ruby-lang.org/en/downloads/branches/ | verificado |
| Rails | 8.1.4.1 (2026-11-04). 8.1 com segurança até 2027-10-10. Rails 8.0 e 8.1 exigem Ruby ≥ 3.2.0 | https://rubyonrails.org/ , https://rubyonrails.org/maintenance , https://guides.rubyonrails.org/upgrading_ruby_on_rails.html | verificado |
| Rails + Ruby 4.0 | Compatibilidade não confirmada nas páginas lidas | n/a | não verificado |
| React | 19.3 (2026-09-09) | https://react.dev/versions | verificado |
| Vite | 8.3.6; exige Node 20.19+ ou 22.12+ | https://vite.dev/releases , https://vite.dev/guide/ | verificado |
| Expo | SDK 58 (React Native 0.88, React 19.3.0, Node ≥ 22.13.x; iOS 16.4+, Xcode 26.4+; Android compileSdk 37, targetSdk 36) | https://docs.expo.dev/versions/latest/ , https://expo.dev/changelog | verificado |
| Expo | Janela de suporte dos SDKs | https://docs.expo.dev/versions/latest/ | não verificado |
| Node.js | LTS mais recente v26.13.0; 22, 24 e 26 em LTS; 20 em fim de vida | https://nodejs.org/en/about/previous-releases | verificado |
| PostgreSQL | 18.6; fim de suporte: 14 em 2026-11-12, 15 em 2027-11-11, 16 em 2028-11-09, 17 em 2029-11-08, 18 em 2030-11-14 | https://www.postgresql.org/support/versioning/ | verificado |
| Sidekiq | 8.1.7. Redis ≥ 7.0 ou Valkey ≥ 7.2; Ruby ≥ 3.2 e Rails ≥ 7.0 (entrada da 8.0.0, não repetida na 8.1) | https://github.com/sidekiq/sidekiq/blob/main/Changes.md | verificado em parte |
| Redis | Versão atual e licença | https://redis.io/docs/latest/ (retornou 404) | não verificado |
| OpenAPI | 3.2.1 (2026-09-10) | https://spec.openapis.org/oas/latest.html | verificado |
| rswag | README declara *"OpenApi 3.0 compatible!"* e *"Seeking maintainers!"*. Última versão não confirmada | https://github.com/rswag/rswag | verificado em parte |

## Provedores de IA

| Fato | Fonte | Estado |
|---|---|---|
| Anthropic: JPEG, PNG, GIF, WebP; até 10 MB em base64; até 8000×8000 px; base64, URL ou Files API | https://platform.claude.com/docs/en/build-with-claude/vision | verificado |
| Anthropic: custo de imagem `⌈w/28⌉ × ⌈h/28⌉` tokens. Os limites de resolução por modelo vieram de resumo | https://platform.claude.com/docs/en/build-with-claude/vision | verificado em parte |
| Anthropic: saída estruturada em `output_config.format` com JSON Schema; sem `minimum`, `maximum`, `multipleOf`, nem recursão; `additionalProperties` deve ser `false` | https://platform.claude.com/docs/en/build-with-claude/structured-outputs | verificado |
| Anthropic, preço por MTok (entrada/saída): Opus 5.5 US$ 4/20; Sonnet 5.5 US$ 2/10; Haiku 5.5 US$ 0,10/0,50 (até 100k tokens por prompt) | https://platform.claude.com/docs/en/about-claude/pricing | verificado |
| Anthropic: *"Retained data is never used for model training without your express permission."* Conteúdo não retido por padrão, salvo modelos cobertos (30 dias). Files API retém até exclusão explícita. Conteúdo sinalizado pode ser retido por até 2 anos (de resumo) | https://platform.claude.com/docs/en/manage-claude/api-and-data-retention | verificado em parte |
| Gemini: PNG, JPEG, WebP, HEIC, HEIF (de resumo); inline até 20 MB; saída estruturada em `response_format` | https://aistudio.google.com/docs/image-understanding , https://aistudio.google.com/docs/structured-output | verificado em parte |
| Gemini 3.8 Flash US$ 0,75/3,75 por MTok até 2026-12-31. Nível gratuito usa o conteúdo para melhorar produtos; nível pago não | https://aistudio.google.com/docs/pricing | verificado |
| OpenAI: PNG, JPEG, WebP e GIF não animado; URL, base64 ou Files API | https://developers.openai.com/api/docs/guides/images-vision | verificado |
| OpenAI: preços e política de retenção e treinamento | https://openai.com/api/pricing/ (retornou 403) | não verificado |

## LGPD

Lei 13.709/2018, texto em https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm. Consultar sempre a redação vigente, pois a página acumula alterações. Este registro não é parecer jurídico.

| Dispositivo | Conteúdo | Estado |
|---|---|---|
| Art. 5, II | Dado referente à saúde é dado pessoal sensível | verificado |
| Art. 8, §§ 1, 4 e 5 | Consentimento por escrito em cláusula destacada; autorizações genéricas são nulas; revogação gratuita e facilitada | verificado |
| Art. 11, I e §1 | Consentimento específico e destacado para finalidades específicas; regras se aplicam ao tratamento que revele dado sensível e possa causar dano | verificado |
| Art. 14 | Tratamento de crianças e adolescentes no melhor interesse; consentimento de responsável para crianças | verificado |
| Arts. 15 e 16 | Término do tratamento e eliminação | verificado |
| Art. 18 | Direitos do titular | verificado |
| Art. 33 | Transferência internacional, por exemplo com cláusulas contratuais ou consentimento específico | verificado |
| Art. 37 | Registro das operações de tratamento | verificado |
| Art. 41 | Encarregado, com identidade e contato públicos | verificado |
| Art. 48 | Comunicação de incidente à autoridade e ao titular | verificado |

## Claude Code

Consultado na documentação atual. Não foi confirmado especificamente na versão 2.1.316 instalada.

| Fato | Fonte | Estado |
|---|---|---|
| Rules em `.claude/rules/`; sem `paths` carregam sempre; com `paths` carregam ao ler ou editar arquivo correspondente | https://code.claude.com/docs/en/memory.md | verificado |
| `CLAUDE.md`: meta de menos de 200 linhas; `@path` para importação, sem reduzir custo de contexto | https://code.claude.com/docs/en/memory.md | verificado |
| Agents: `name` e `description` obrigatórios; `tools` é lista de permissão; Bash não é somente leitura; especificador em `disallowedTools` remove a ferramenta inteira | https://code.claude.com/docs/en/sub-agents.md | verificado |
| Skills: `.claude/skills/<nome>/SKILL.md`; `description` recomendada; `disable-model-invocation`; `$ARGUMENTS`; menos de 500 linhas | https://code.claude.com/docs/en/skills.md | verificado |
| Permissões: ordem deny, ask, allow; `Read(./.env)`; o `deny` de `Read` não é declarado como bloqueio de `cat` via Bash | https://code.claude.com/docs/en/permissions.md | verificado |
| `enabledPlugins` em projeto não baixa o plugin; cada pessoa roda `claude plugin install <nome>@<marketplace> --scope project` | https://code.claude.com/docs/en/plugins/install.md | verificado |
| `/reload-plugins` carregou o plugin instalado nesta sessão (2026-11-05) | Execução local | verificado |
| Hooks: eventos, contrato de entrada e código de saída 2 | https://code.claude.com/docs/en/hooks.md | verificado |

## Superpowers

| Fato | Fonte | Estado |
|---|---|---|
| Plugin `superpowers@claude-plugins-official`, versão 7.0.0, commit `bb92a77741419a4ab5f06e711a283343f1ada0c3`, licença MIT, autor Jesse Vincent | Saída de `claude plugin list` e `plugin.json` da instalação | verificado |
| Skills instaladas: `brainstorming`, `diagnosing-superpowers`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `requesting-code-review`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-plans`, `writing-skills` | Listagem do diretório `skills` da instalação | verificado |
