# Design da Fase 01 — Foundation & Developer Experience

- **Data:** 2026-11-06
- **Escopo e critérios:** [documento da fase](../../roadmap/phases/PHASE_01_FOUNDATION.md), que continua sendo a fonte dos `AC-`. Este design só registra o que aquele documento deixa em aberto.
- **Fontes:** [registro de fontes](../../architecture/EXTERNAL_SOURCES.md), consultado em 2026-11-06.

## Intenção

Provar que a stack funciona de ponta a ponta, antes de existir qualquer regra de negócio. Uma pessoa clona o repositório, sobe tudo seguindo a documentação, vê web e mobile mostrando o estado real da API, e o CI reprova defeitos de verdade. A fase seguinte (Identity) precisa encontrar uma base confiável, sem decisões de ferramenta pendentes.

## Objetivos

- Cumprir `AC-01-01` a `AC-01-10`, com a evidência que cada um exige.
- Fechar as ADRs 0002, 0003 e 0014, e a parte de fila da 0004, com decisão e evidência de execução.
- Eliminar a falha conhecida do check `scope`, por a linha 01 entrar em desenvolvimento, e tirá-la do `CLAUDE.md` no encerramento.

## Fora de escopo

- Outbox, cadastro, modelos de negócio, integrações externas e telas de produto.
- Deploy, imagem Docker da API e build de distribuição do mobile (M1). A pasta `docker/` só recebe conteúdo se um critério exigir, e hoje nenhum exige.
- Métricas e alertas que [OBSERVABILITY.md](../../engineering/OBSERVABILITY.md) lista "a partir da Fase 01", como taxa de erro, filas e jobs mortos: nenhum critério da fase os pede. O documento passa a marcá-los para o M1. A verificação própria do Sidekiq também vai para o M1.
- Etapa de migrations do CI: sem migrations, ela nada provaria. Entra na primeira fase que criar uma.

## O que não pode acontecer

- Declarar uma versão ou ferramenta como decidida sem tê-la executado.
- CI com etapa que continua em caso de erro, ou que passa sem verificar nada.
- Segredo real no repositório, que agora é **público**. Defeitos plantados usam só valores falsos, porque ficam visíveis para sempre no histórico de PRs.
- Dado sensível em log ou no monitoramento.
- Tela de demonstração virar início de produto.

## Decisões do responsável (2026-11-06)

| Decisão | Valor |
|---|---|
| Visibilidade do repositório | Público, em `giovanic/nexora`, sem `LICENSE`: código visível, sem permissão de reuso |
| Autor dos commits | `giovanic.miranda@gmail.com`, configurado só neste repositório |
| Fila | Sidekiq, mantendo a stack de referência |
| Serviço de fila | Valkey 9.1, sujeito ao teste real com o Sidekiq |
| Monitoramento de erros | Sentry, plano gratuito, região UE se o plano permitir. O responsável cria a conta e fornece os DSNs |

## Decisões de engenharia, a confirmar na aprovação

Foram tomadas por quem escreveu este design, e não pelo responsável.

### Versões

Candidatas, fixadas só depois da aplicação mínima rodar:

| Item | Candidata | Alternativa se falhar | Por quê |
|---|---|---|---|
| Ruby | 4.0.9 | 3.4.12 | Proposta da ADR 0002. As fontes não afirmam a compatibilidade com Rails 8.1 |
| Rails | 8.1.4.1 | n/a | Atual. **Só recebe correção de segurança, e até 2027-10-10:** registrar como risco na ADR 0002 |
| Node | 26 LTS | 24 LTS, depois 22 LTS | "O LTS mais recente aceito pelo Expo"; a Expo publica só o mínimo |
| PostgreSQL | 18.6 | n/a | Maior suporte, até 2030. Imagem conferida no Docker Hub |
| Valkey | 9.1.3 | Redis 8, se o responsável aprovar | Licença BSD-3. Imagem conferida no Docker Hub |
| TypeScript nos clientes | 6.0.x | n/a | O `typescript-eslint` aceita até `<6.1.0`, e o template da Expo já usa a 6.0. A 7 fica de fora |

Fixação: `.ruby-version`, `.nvmrc` (o `nvm` já está nesta máquina), tags exatas de imagem e lockfiles.

### Validação antes de fixar

Uma aplicação mínima em diretório temporário, fora do repositório e descartada depois, executa de verdade: Rails, Sidekiq com Valkey, rspec-rails, openapi_first, lograge e sentry-rails em Ruby 4.0.9; e o Packwerk contra violações plantadas. Nos clientes, build e testes em Node 26. O resultado, inclusive falhas, vai para as ADRs.

### Pastas geradas, item por item

| Pasta | Decisão | Motivo |
|---|---|---|
| `apps/api` | **Gerar de novo**, com `rails new --api --database=postgresql`, sem testes padrão, Solid Queue/Cache/Cable, Kamal, Thruster, Active Storage, Action Mailer, Action Mailbox, Action Text, Action Cable e CI próprio | Quase tudo diverge: Ruby, fila, testes e deploy. Gerar é mais limpo que remover peça por peça |
| `apps/api/config/credentials.yml.enc` | **Remover**, sem usar credenciais do Rails | Configuração só por variáveis de ambiente. `RAILS_MASTER_KEY` sai de `ENVIRONMENT_VARIABLES.md` |
| `apps/web` | **Ajustar** | Vite e React estão nas versões certas. Trocar oxlint por ESLint e TypeScript 7 por 6.0, adicionar testes, remover a página de demonstração |
| `apps/mobile` | **Ajustar** | Expo SDK 58 está certo. Remover a demonstração, as dependências que ela usava e `scripts/reset-project.js`. Manter Expo Router |
| `apps/mobile/.claude/settings.json` | **Remover** | Habilita um plugin que não passou pelo processo. O harness fica na raiz |
| `apps/mobile/AGENTS.md`, `LICENSE`, `.vscode` | **Remover** | A licença do template não é a do produto. As duas orientações úteis do `AGENTS.md`, usar `npx expo install` e consultar a doc da versão do SDK, vão para `CODING_STANDARDS.md` |
| `packages/contracts` | **Usar**, justificado pela geração de tipos (ADR 0014) | Já estava previsto |

### Contrato (ADR 0014)

- **Contrato primeiro,** em `packages/contracts/openapi.yaml`, escrito em **OpenAPI 3.1**. A 3.2.1 é a mais recente, mas nenhuma ferramenta avaliada declara suporte a ela.
- **Validação no backend:** `openapi_first`, só nos testes. Tem release de 2026-11-03 e foi feito para teste de contrato. O `committee` fica como alternativa, por ter mais restrições declaradas em 3.x.
- **Tipos:** `openapi-typescript` em `packages/contracts`, com TypeScript 5 isolado nesse pacote, porque a ferramenta declara `^5.x`. Última release em 2026-02-11: registrar como risco. O custo de troca é baixo, porque ela só gera um arquivo de tipos.
- **Tipos gerados são versionados,** e o CI falha se regenerar produzir diferença.
- **Sem `openapi-fetch`:** um único endpoint não justifica outra dependência em produção. Os clientes usam `fetch`, com os tipos gerados.
- Web e mobile consomem o pacote por workspaces do npm na raiz. Se o Metro não resolver isso bem, o pacote gera o arquivo em cada cliente: a decisão sai do teste real.

### Limites de domínio (ADR 0003)

Recomendação: **teste próprio em RSpec, com o Prism** (parser que vem com o Ruby), sem dependência nova. Motivo: nossa regra central é "só `<Contexto>::Api`", e o núcleo do Packwerk verifica apenas dependência entre pacotes, não visibilidade. O Packwerk é executado na validação contra as mesmas violações, e o resultado entra na ADR. Se ele cobrir a regra com menos manutenção, a recomendação muda.

- O teste percorre `app/domains/**/*.rb`, resolve as referências a constantes e falha quando:
  - uma referência a outro contexto não passa por `<Contexto>::Api`;
  - a dependência não consta da lista permitida, derivada das regras e do mapa em [DOMAIN_MODEL.md](../../architecture/DOMAIN_MODEL.md), que proíbe depender de Gamification, Notifications e Progress & Analytics.
- **Limite conhecido, registrado na ADR:** não detecta `constantize` nem SQL direto. Isso fica com os revisores.
- Namespaces, vazios com `.keep`: `Identity`, `UserProfile`, `Nutrition`, `FoodAi`, `FoodCatalog`, `Activities`, `StravaIntegration`, `Goals`, `Missions`, `Gamification`, `Notifications`, `ProgressAnalytics`, além de `shared/`.

### API

- Porta **3010**, porque 3000 a 3002 estão ocupadas nesta máquina.
- `/health/live`: só confirma que o processo responde, sem tocar em dependências.
- `/health/ready`: PostgreSQL e Valkey, com tempo limite curto. Responde 503 quando um falha, indicando qual, sem detalhes internos.
- Formato de erro de [API_DESIGN.md](../../architecture/API_DESIGN.md) também em 404 de rota e em 500, sem vazar exceção.
- CORS com `rack-cors`, a partir de `ALLOWED_ORIGINS`. Sem origem configurada, nenhuma é liberada.
- **Rota de prova do job:** `POST /internal/smoke_jobs`, que enfileira um job, e `GET` do resultado. Montada só fora de produção, com teste que comprova isso. O job grava um marcador com expiração no Valkey, e nada no PostgreSQL.
- Sem variáveis no desenvolvimento: `database.yml` e Sidekiq têm padrões locais, e produção falha ao iniciar sem as obrigatórias. Assim não há `dotenv` nem cópia de `.env` para subir.
- `bin/rails` usa RSpec, RuboCop (`rubocop-rails-omakase`), Brakeman e `bundler-audit`.

### Serviços locais

`docker-compose.yml` na raiz, ligado só a `127.0.0.1`, com PostgreSQL em **5434** e Valkey em **6380**. As portas padrão desta máquina estão ocupadas por outro projeto. A variável continua `REDIS_URL`, que é o nome que o Sidekiq lê.

### Logs e erros

- **`lograge`** para uma linha JSON por requisição, e o formatador JSON do próprio Sidekiq nos jobs. O `rails_semantic_logger` não se justifica para só isso.
- **`correlation_id`:** vem do cabeçalho `X-Correlation-Id` ou é gerado, fica em `Current`, e passa ao job por middleware de cliente e de servidor do Sidekiq. Volta na resposta. Valores recebidos são validados, para evitar injeção em log.
- **Filtro de parâmetros** ampliado, com teste que percorre uma requisição com dados sensíveis e confere a saída do log.
- **Sentry:** `sentry-ruby`, `sentry-rails`, `sentry-sidekiq`, `@sentry/react`, `@sentry/react-native`. Envio de dados pessoais desligado em todas, e filtro antes do envio, com teste. Sem DSN, o SDK fica inativo: testes e CI não enviam nada.

### Clientes

Cada um tem uma única tela, "Estado da API", com carregando, sucesso e erro, sem marca nem texto de produto. Separação entre hook que busca e componente que apresenta, como em `CODING_STANDARDS.md`.

| | Web | Mobile |
|---|---|---|
| Tipos | `tsc --noEmit`, TypeScript 6.0 | `tsc --noEmit`, TypeScript 6.0 |
| Lint | ESLint com `typescript-eslint` | ESLint com `eslint-config-expo` |
| Testes | Vitest, Testing Library, jsdom | `jest-expo`, Jest 30, Testing Library Native |

**Mobile, caminho local:** aparelho Android físico, como a Expo recomenda. Começa com Expo Go. Se o SDK do Sentry ou o Expo Go não servirem, passa a development build. Como o projeto roda no WSL 2, a rede entre o aparelho e o WSL é o ponto incerto: o caminho que funcionar vai para `LOCAL_DEVELOPMENT.md`. O responsável segura o aparelho para a captura de tela de `AC-01-04`.

### CI (`.github/workflows/ci.yml`)

- Jobs separados para harness, segredos, API, contrato, web e mobile, todos bloqueantes e sem `continue-on-error`.
- Ações fixadas por commit, e `permissions: contents: read`.
- API com `postgres:18.6` e `valkey/valkey:9.1.3` reais como serviços.
- **Segredos:** binário do Gitleaks v8.30.1, com checksum conferido, varrendo o histórico. Sem `gitleaks-action`, que tem licença própria. A ferramenta só recebe correção de segurança e os autores migraram para o Betterleaks, ainda em release candidate da v2. Reavaliar no M1; trocar custa uma etapa do CI.
- **Auditorias:** Brakeman, `bundler-audit` e `npm audit --audit-level=high`, cada um em seu job.
- **Licença do Brakeman:** registrar como pendência da revisão jurídica. O texto cita "analisar o software do licenciado" como uso não comercial, mas não trata de empresa com fins lucrativos.
- **Proteção de `main`:** exigir o CI verde, via `gh api`, depois que os nomes dos jobs estabilizarem. Como o repositório é público, deve estar disponível; a execução confirma.

### Provas de defeito (`AC-01-05`, `AC-01-06`, `AC-01-09`)

Uma branch descartável por defeito, com PR aberto, execução registrada e PR fechado:

- teste quebrado na API, na web e no mobile;
- erro de lint na API, na web e no mobile;
- erro de tipo na web e no mobile;
- violação de limite de domínio;
- contrato divergente da implementação;
- segredo falso, com formato que o Gitleaks detecta.

O relatório cita o link de cada execução. As provas ficam **públicas**.

### Git

- O trabalho acontece em `phase/01-foundation`, em worktree, a partir de `main`.
- Os documentos já alterados no kickoff vão num primeiro PR só de documentação, para `main` mostrar o estado correto. `STATUS.md` é a fonte única, e uma sessão nova lê a `main`.
- A aprovação deste design e do plano **ainda não autoriza** commit nem push. O plano pede essa autorização de forma explícita.

## Restrições

- Regras de `.claude/rules/` e do `CLAUDE.md`, sobretudo TDD em todo código de produto e evidência por execução.
- `.claude/settings.json` nega `Read(**/.env.*)`, e isso bloqueia a leitura de `.env.example`. O arquivo é criado uma vez com a ferramenta de escrita, listando só nomes e valores locais óbvios. Mudanças posteriores são do responsável, salvo ajuste da regra.
- `git push --force*`, `git reset --hard*`, `git clean *` e `rm -rf *` são negados. Remover as pastas geradas usa `git rm`.
- Qualquer dependência não listada aqui precisa de justificativa no plano: por que, alternativa, manutenção e licença.

## Ações do responsável

| Ação | Necessária para | Situação |
|---|---|---|
| `gh auth login` | Primeiro PR e `AC-01-05`, `AC-01-06` | Feito: logado como `giovanic`, com `gh` 2.4.0 do pacote do Ubuntu. Trocar pelo pacote oficial se faltar algum recurso |
| Criar a organização no Sentry, região UE se disponível, e fornecer os DSNs | `AC-01-07`, demonstração | A fazer. Confirmar a região na tela de criação |
| Segurar o aparelho Android e capturar a tela | `AC-01-01`, `AC-01-04` | Durante a execução |
| Opcional: apagar e recriar o repositório, para eliminar os hashes antigos com o e-mail de trabalho | Privacidade | `7bdaf84` e `d2c573b` seguem acessíveis pelo hash. Só é simples **antes** de haver CI e PRs |

## Riscos

| Risco | Efeito | Resposta |
|---|---|---|
| Ruby 4.0 quebrar alguma gem | Retrabalho | Validação antes de fixar; Ruby 3.4.12 como alternativa |
| Valkey 9.1 divergir do que o Sidekiq espera | Fila instável | Teste real com o Sidekiq; o Redis 8 só com aprovação |
| Workspaces npm com Metro | Tipos não resolvidos no mobile | Teste real; geração por cliente como alternativa |
| Rede entre aparelho e WSL 2 | Atraso em `AC-01-01` e `AC-01-04` | Documentar o caminho que funcionar; emulador no Windows como alternativa |
| Rails 8.1 sem correção de bugs | Bug sem conserto até migrar | Registrar na ADR 0002 e reavaliar quando sair nova linha |
| Termos do plano gratuito do Sentry | Mudança de plano ou ferramenta | Pendência da revisão jurídica, antes do M1 |
| Repositório público | Exposição de documentação, decisões e histórico | Decisão do responsável; varredura de segredos no CI |

## O que fica para quem constrói

Nomes de classes e arquivos internos, ordem exata das tarefas, estilo das telas de estado, tempos limite, forma do relatório de contrato no CI e organização interna dos jobs, desde que respeitem o que está acima.
