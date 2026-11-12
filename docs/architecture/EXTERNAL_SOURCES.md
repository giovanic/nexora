# Registro de fontes externas

Toda decisão que depende de informação externa aponta para este registro. Regra da seção 11 do [Master Prompt](../product/MASTER_PROMPT.md): fonte oficial, versão confirmada, data da consulta e nada inventado.

- **Consulta:** as entradas foram lidas em **2026-11-05**, salvo indicação na seção.
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

Reconsultadas em **2026-11-06**, no início da Fase 01. Datas e versões de gems e pacotes vêm das APIs de `rubygems.org` e `registry.npmjs.org`.

| Ferramenta | Fato | Fonte | Estado |
|---|---|---|---|
| Ruby | Estável 4.0.9; 3.4.12 também listada como estável. 4.0 e 3.4 em manutenção normal. 3.3 só segurança, fim esperado em 2027-03-31 | https://www.ruby-lang.org/en/downloads/ e https://www.ruby-lang.org/en/downloads/branches/ | verificado |
| Rails | 8.1.4.1 (2026-11-04). 8.1: correção de bugs até 2026-10-10, já encerrada, e segurança até 2027-10-10. 8.0: segurança até 2026-11-07. Rails 8.0 e 8.1 exigem Ruby ≥ 3.2.0 | https://rubyonrails.org/ , https://rubyonrails.org/maintenance , https://guides.rubyonrails.org/upgrading_ruby_on_rails.html | verificado |
| Rails + Ruby 4.0 | `rails.gemspec` da 8-1-stable exige `>= 3.2.0`; as notas da 8.1 e o guia de atualização não citam Ruby 4.0. As fontes não afirmam a compatibilidade, mas a execução local de 2026-11-06 funcionou ([ADR 0002](decisions/0002-technology-baseline.md)) | https://raw.githubusercontent.com/rails/rails/8-1-stable/rails.gemspec , https://guides.rubyonrails.org/8_1_release_notes.html e execução local | verificado por execução |
| Sidekiq + Valkey 9.1 | Job real processado por `sidekiq` 8.1.7 em `valkey/valkey:9.1.3`. A fonte declara só o mínimo, Valkey ≥ 7.2 | Execução local de 2026-11-06 | verificado por execução |
| React | 19.3 (2026-09-09) | https://react.dev/versions | verificado |
| Vite | 8.3.6; exige Node 20.19+ ou 22.12+ | https://vite.dev/releases , https://vite.dev/guide/ | verificado |
| Expo | SDK 58 (React Native 0.88, React 19.3.0, Node ≥ 22.13.x; iOS 16.4+, Xcode 26.4+; Android compileSdk 37, targetSdk 36). Três SDKs por ano | https://docs.expo.dev/versions/latest/ , https://expo.dev/changelog | verificado |
| Expo | Janela de suporte dos SDKs: não declarada nas páginas lidas | https://docs.expo.dev/versions/latest/ , https://docs.expo.dev/more/release-statuses.md | não verificado |
| Expo | Aparelho real recomendado para desenvolver. Expo Go é *"a playground app"*; development build é o caminho para produção. `expo.dev/go` exibe o SDK 58 como atual, sem afirmar suporte em frase | https://docs.expo.dev/get-started/set-up-your-environment/ , https://expo.dev/go | verificado em parte |
| Node.js | LTS mais recente v26.13.0; 22, 24 e 26 em LTS; 20 em fim de vida | https://nodejs.org/en/about/previous-releases | verificado |
| PostgreSQL | 18.6 e 17.11; fim de suporte: 14 em 2026-11-12, 15 em 2027-11-11, 16 em 2028-11-09, 17 em 2029-11-08, 18 em 2030-11-14 | https://www.postgresql.org/support/versioning/ | verificado |
| Sidekiq | 8.1.7 (2026-08-17), licença LGPL-3.0, Ruby ≥ 3.2. Redis ≥ 7.0 (entrada da 8.0.1) ou Valkey ≥ 7.2, e Rails ≥ 7.0 (entrada da 8.0.0, não repetida na 8.1) | https://github.com/sidekiq/sidekiq/blob/main/Changes.md , https://raw.githubusercontent.com/sidekiq/sidekiq/main/sidekiq.gemspec | verificado |
| Redis | 8.10.3 (2026-10-26). Licença: até 7.2, BSD-3-Clause; 7.4, RSALv2 ou SSPLv1; a partir de 8.0, RSALv2, SSPLv1 ou AGPLv3, à escolha de quem usa | https://github.com/redis/redis/releases , https://redis.io/legal/licenses/ | verificado |
| Valkey | 9.1.3 (2026-10-26), licença BSD-3-Clause. Fork do Redis anterior à mudança de licença | https://github.com/valkey-io/valkey/releases , https://github.com/valkey-io/valkey | verificado |
| OpenAPI | 3.2.1 (2026-09-10) | https://spec.openapis.org/oas/latest.html | verificado |
| rswag | README declara *"OpenApi 3.0 compatible!"* e *"Seeking maintainers!"*. Última versão não confirmada | https://github.com/rswag/rswag | verificado em parte |

## Fase 02: identidade, segurança e privacidade

Consultado em **2026-11-11**, no início da Fase 02. Guias do Rails 8.1.4.1 e do Expo SDK 58. Versões de gems vêm da API de `rubygems.org` e da atividade, dos repositórios no GitHub.

| Fato | Fonte | Estado |
|---|---|---|
| O gerador de autenticação (`bin/rails generate authentication`, desde o Rails 8.0) cria um modelo `Session` no banco e, no código do concern `Authentication`, resume a sessão só por cookie assinado: `cookies.signed[:session_id]`, gravado com `httponly: true, same_site: :lax`. Não gera cadastro. O guia não cita token de API nem JWT, então o fluxo por token do mobile é código próprio | https://guides.rubyonrails.org/security.html e `authentication.rb.tt` da tag v8.1.4.1 em https://github.com/rails/rails | verificado (o "só cookie" vem do código do gerador, e não de frase do guia) |
| `has_secure_password` usa a gem `bcrypt`, valida tamanho máximo de 72 bytes e não valida tamanho mínimo nem complexidade | https://guides.rubyonrails.org/security.html | verificado |
| Token de recuperação de senha: *"The link is valid for 15 minutes by default"*, configurável | https://guides.rubyonrails.org/security.html | verificado |
| `rate_limit to:, within:, only:` é nativo. O contador fica no cache store: padrão `config.action_controller.cache_store`, que herda `config.cache_store`. `by:` padrão é `request.remote_ip`, `with:` padrão levanta `TooManyRequests` (429), `store:` aceita outro store, e `name:` é obrigatório para vários limites no mesmo controller | https://api.rubyonrails.org/classes/ActionController/RateLimiting/ClassMethods.html e https://guides.rubyonrails.org/security.html | verificado |
| Active Record Encryption: chaves `primary_key`, `deterministic_key` e `key_derivation_salt`, por credentials (recomendado pelo guia) ou por `config.active_record.encryption.*`, com o exemplo `ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"]` e equivalentes. Sem `deterministic_key`, a cifragem determinística fica desabilitada. Não versionar chaves | https://guides.rubyonrails.org/active_record_encryption.html | verificado |
| Cifragem determinística permite consulta por igualdade e índice único, ao custo de texto igual gerar cifra igual. `downcase: true` normaliza antes de cifrar e perde a caixa original. Rotação de chaves não é suportada para a determinística. As propriedades de cifragem não podem mudar, ou o índice deixa de funcionar | https://guides.rubyonrails.org/active_record_encryption.html | verificado |
| Expo SecureStore (SDK 58, pacote ~58.0.3, `npx expo install expo-secure-store`): iOS grava no Keychain (`kSecClassGenericPassword`) e Android em SharedPreferences cifradas pelo Keystore. Sem limite imposto pelo Expo, mas versões antigas do iOS recusavam valores acima de cerca de 2048 bytes. Funciona no Expo Go. No iOS os dados podem sobreviver à reinstalação com o mesmo bundle ID, sem garantia, e no Android não sobrevivem. Padrão de acessibilidade: `WHEN_UNLOCKED` | https://docs.expo.dev/versions/latest/sdk/securestore/ | verificado |
| OWASP, sessões: identificador com ao menos 64 bits de entropia, de gerador criptográfico; renovar o identificador após mudança de privilégio (login); invalidar também no servidor ao sair; timeout absoluto e por inatividade; não guardar token em `localStorage` nem `sessionStorage`; cookies com `Secure`, `HttpOnly` e `SameSite` | https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html | verificado |
| OWASP, recuperação de senha: mesma resposta para conta existente e inexistente, com tempo uniforme; token aleatório criptográfico, de uso único, com validade e guardado de forma segura; limitar pedidos por conta; não alterar a conta antes de apresentar token válido; oferecer ou aplicar o fim das sessões existentes após a troca | https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html | verificado |
| `bcrypt` (gem): 3.1.22 (2026-03-18) é a última | https://rubygems.org/gems/bcrypt | verificado |
| `sidekiq-cron`: 2.4.0 (2026-05-06), MIT; depende de `sidekiq >= 6.5.0`, `fugit`, `cronex` e `globalid`. Mantida: commits em 2026-11-06 (repositório sidekiq-cron/sidekiq-cron), não arquivado, versões 2.1.0 a 2.4.0 entre 2025-01-20 e 2026-05-06. Os commits após 2.4.0 ainda não têm release | https://rubygems.org/gems/sidekiq-cron e https://github.com/sidekiq-cron/sidekiq-cron | verificado |
| Gem `redis` (redis-rb): 6.0.0 (2026-07-31), MIT, exige Ruby 3.2+ e servidor Redis 6.0+ (declarado pela fonte), com dependência exata em `redis-client = 0.30.1`. Mantida: commits em 2026-11-06, não arquivada. A 6.0 passa a usar RESP3 por padrão; a anterior, 5.4.1, é de 2025-07-17 | https://rubygems.org/gems/redis e https://github.com/redis/redis-rb/releases/tag/v6.0.0 | verificado |
| Compatibilidade da `redis` 6.0.0 com Valkey 9.1 e com o Sidekiq 8.1.7 (que usa `redis-client`) | Não consultada | não verificado (conferir com execução real na tarefa que adicionar a gem) |

## Ferramentas candidatas da Fase 01

Consultadas em **2026-11-06**. Licenças não têm parecer jurídico.

| Ferramenta | Fato | Fonte | Estado |
|---|---|---|---|
| openapi_first | 4.3.0 (2026-11-03), MIT, Ruby ≥ 3.3. Valida contra OpenAPI 3.0 ou 3.1, com teste de contrato em rack-test e relatório de cobertura. 3.2 não é citada | https://github.com/ahx/openapi_first , https://rubygems.org/gems/openapi_first | verificado |
| committee | 5.6.4 (2026-09-21), MIT. OpenAPI 3.0 e 3.1, sem `if`/`then`/`else`, `unevaluatedProperties`, `patternProperties` e `$dynamicRef`. 3.2 não é citada | https://github.com/interagent/committee , https://rubygems.org/gems/committee | verificado |
| openapi-typescript | 7.13.0 (2026-02-11), MIT. OpenAPI 3.0 e 3.1. Declara `typescript` `^5.x` como dependência par | https://openapi-ts.dev/introduction , https://registry.npmjs.org/openapi-typescript | verificado |
| Packwerk | 3.3.1 (2026-08-26), MIT, Ruby ≥ 3.3. *"Packwerk ships with dependency boundary checking only."* A verificação de visibilidade não vem no núcleo. Exige Zeitwerk | https://github.com/Shopify/packwerk/blob/main/USAGE.md , https://rubygems.org/gems/packwerk | verificado |
| Gitleaks | v8.30.1 (2026-03-21), MIT, repositório ativo em 2026-10-28. *"Future releases will be security patches only."* Sai com código 1 ao achar vazamento. `gitleaks git` varre o histórico | https://github.com/gitleaks/gitleaks | verificado |
| gitleaks-action | Licença própria desde a v2. Chave exigida para organizações, não para contas pessoais | https://github.com/gitleaks/gitleaks-action/blob/master/LICENSE.txt | verificado |
| Betterleaks | v1.10.0 (2026-11-04), MIT, dos autores do Gitleaks. v2 em release candidate; arquivos de configuração do Gitleaks não são declarados compatíveis | https://github.com/betterleaks/betterleaks | verificado em parte |
| Brakeman | 8.1.0 (2026-10-01). "Brakeman Public Use License": uso comercial exige licença paga, mas *"Using the Software to analyze Licensee's software."* consta como exemplo de uso não comercial. O texto não trata do CI de empresa com fins lucrativos, e manda consultar o mantenedor em caso de dúvida | https://raw.githubusercontent.com/presidentbeef/brakeman/main/LICENSE.md | verificado (o enquadramento do nosso caso é questão jurídica) |
| bundler-audit | 0.9.3 (2025-11-28), GPL-3.0-or-later | https://rubygems.org/gems/bundler-audit | verificado |
| rspec-rails | 8.1.0 (2026-11-06), MIT. A linha 8.x cobre Rails 8.1, 8.0 e 7.2 | https://github.com/rspec/rspec-rails , https://rubygems.org/gems/rspec-rails | verificado |
| lograge | 0.15.1 (2026-09-29), MIT. Rails 8.1 e MRI 4.0 declarados verdes no CI | https://github.com/roidrage/lograge | verificado |
| rails_semantic_logger | 5.2.0 (2026-09-05), Apache-2.0, Ruby ≥ 3.2 | https://rubygems.org/gems/rails_semantic_logger | verificado |
| rack-cors | 3.0.0 (2025-05-16), MIT | https://rubygems.org/gems/rack-cors | verificado |
| Sentry: Expo Go | Em Expo Go, o SDK desliga a camada nativa e captura só erros JS. `beforeSend` não é repassado ao SDK nativo, então crash nativo não passa pelo filtro | Código de `@sentry/react-native` 8.28 (`dist/js/options.js`, `dist/js/wrapper.js`) | verificado por leitura do código |
| Expo Go no WSL 2 | Emulador Android no Windows alcança a API e o Metro pelo IP interno do WSL, sem `adb reverse` nem túnel. Expo Go 58.0.5 | Execução local de 2026-11-07 | verificado por execução |
| TypeScript | 7.0.2 (2026-07-08). `typescript-eslint` 8.72.1 aceita `>=4.8.4 <6.1.0`, portanto não aceita a 7 | https://registry.npmjs.org/typescript , https://registry.npmjs.org/typescript-eslint | verificado |
| Testes dos clientes | vitest 5.1.0 (Node `^22.12 \|\| ^24 \|\| >=26`); jsdom 31.0.0 (Node `^22.22.2 \|\| ^24.15 \|\| >=26`); @testing-library/react 16.3.3; @testing-library/react-native 14.1.0; jest-expo 58.0.14, que no SDK 58 exige Jest 30; eslint 10.14.0; eslint-config-expo 58.0.4 | https://registry.npmjs.org/ , https://docs.expo.dev/develop/unit-testing/ , https://docs.expo.dev/guides/using-eslint/ | verificado |
| Sentry: plano | Developer gratuito: um usuário, 5 mil erros, retenção de 30 dias. A seção 17 dos termos limita "No-Charge Products" e não diz se o plano entra nela. Uso limitado a *"internal business purposes"* | https://sentry.io/pricing/ , https://sentry.io/terms/ | verificado em parte |
| Sentry: dados | Armazenamento em US (Iowa) ou EU (Frankfurt), escolhido ao criar a organização e sem troca posterior; contas e configurações ficam nos EUA. DPA disponível. Escolha da região no plano gratuito não confirmada | https://docs.sentry.io/organization/data-storage-location/ , https://sentry.io/legal/dpa/ | verificado em parte |
| Sentry: SDKs | sentry-ruby, sentry-rails e sentry-sidekiq 7.2.0; @sentry/react 11.11.0; @sentry/react-native 8.34.0, para Expo SDK 50 ou superior. Rails não envia identidade por padrão; React envia, e desliga com `dataCollection`; o exemplo do Expo traz `sendDefaultPii: true` | https://docs.sentry.io/platforms/ruby/guides/rails/ , https://docs.sentry.io/platforms/javascript/guides/react/ , https://docs.sentry.io/platforms/react-native/manual-setup/expo/ | verificado |
| GitHub Actions | Plano Free inclui US$ 12 por mês de computação em repositório privado (cerca de 2.000 minutos Linux, por cálculo nosso, a US$ 0,006 por minuto); runners padrão são gratuitos em repositório público | https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions | verificado |
| GitHub: proteção de branch | *Protected branches* em repositório privado aparece a partir do plano Pro. "Required status checks" e regras de repositório no plano Free não são citados | https://docs.github.com/en/get-started/learning-about-github/githubs-plans | verificado em parte |
| `gh` | Instalação oficial por pacote Debian, com repositório próprio. Pacote comunitário do Ubuntu `2.45.x`/`2.46.x` declarado quebrado. WSL não é citado | https://github.com/cli/cli/blob/trunk/docs/install_linux.md | verificado |
| setup-ruby | Suporta MRI até 4.1.0-preview1; recomenda versão curta, como `'4.0'` | https://github.com/ruby/setup-ruby | verificado |

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
