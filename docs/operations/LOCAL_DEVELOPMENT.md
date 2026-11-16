# Desenvolvimento local

Comandos testados a partir de um clone limpo em 2026-11-07, no WSL 2 com Ubuntu, conforme `AC-01-01`. O desenvolvimento não precisa de `.env`: os padrões locais batem com o `docker-compose.yml`.

## Pré-requisitos

| Ferramenta | Versão | Fixada em |
|---|---|---|
| Docker com Compose | 27 ou superior | n/a |
| Ruby, por `rbenv` | 4.0.9 | `apps/api/.ruby-version` |
| Node, por `nvm` | 26.13.0 | `.nvmrc` |
| Git, Bash e Python 3 | n/a | n/a |
| Android SDK com emulador, no Windows, para o mobile | Android 16 ou superior | n/a |

Dependências de sistema para compilar as gems no Ubuntu: `build-essential`, `libpq-dev`, `libyaml-dev`, `libffi-dev`.

**Fase 03, imagens:** a gem `ruby-vips` carrega a biblioteca nativa libvips em tempo de execução, então ela precisa estar instalada: `sudo apt install libvips42` (verificado nesta máquina: `libvips42` 8.12.1). No CI do `ubuntu-24.04` o pacote se chama `libvips42t64`. Para **HEIC e HEIF** (fotos do iPhone) a libvips usa a `libheif`, e o pacote `libheif1` do Ubuntu traz só os decodificadores AV1: HEVC, o codec do HEIC do iPhone, exige o plugin `libde265`. Nesta máquina, `libheif1` 1.12 e `libde265-0` estão instalados. No CI, o passo instala `libheif-plugin-libde265` junto da `libvips42t64`. Sem o suporte a HEIC, o spec que monta uma foto HEIC é pulado, e o envio de HEIC real falharia com `invalid_photo`.

## Subir tudo

Cada processo fica em um terminal próprio, a partir da raiz do repositório.

**Serviços de apoio:** PostgreSQL em `127.0.0.1:5434`, Valkey em `127.0.0.1:6380` e, desde a Fase 03, o armazenamento de fotos compatível com S3, o **SeaweedFS** 4.53 (`chrislusf/seaweedfs:4.53`), em `127.0.0.1:8334`. Ele só escuta no loopback, e as chaves de `infra/seaweedfs/s3.json` valem apenas para desenvolvimento. O bucket `app-dev-photos` é criado no primeiro uso.

```bash
docker compose up -d --wait
```

**API**, em `http://localhost:3010`:

```bash
cd apps/api
bundle install
bin/rails db:prepare
bin/rails server -p 3010 -b 0.0.0.0
```

O `-p 3010` é obrigatório: `bin/rails server` ignora a porta do `puma.rb` e tentaria a 3000. O `-b 0.0.0.0` é necessário só para o emulador alcançar a API.

**Catálogo de alimentos (Fase 03):** carrega as bases licenciadas (subconjunto do USDA FoodData Central e as composições próprias). É idempotente; rode depois de `db:prepare` e sempre que os arquivos de `apps/api/db/catalog/` mudarem.

```bash
cd apps/api
bin/rails food_catalog:load
```

**Sidekiq:**

```bash
cd apps/api
bundle exec sidekiq -C config/sidekiq.yml
```

**Web**, em `http://localhost:5173`:

```bash
nvm use
npm ci
npm run dev -w apps/web
```

**Mobile:** veja a seção seguinte.

### Food AI na Fase 03

- **Sem provedor de IA:** nenhuma chave existe nesta fase (as chaves ficam para a Fase 07). Sem `FOOD_AI_PROVIDER`, a API sobe, mas todo envio de foto responde `consent_operator_mismatch`, porque o consentimento `food_photo_ai` está na v1, sem operador. A análise de ponta a ponta só roda com dublê, na suíte (`FakeAdapter`).
- **Sidekiq** também executa a análise, as retenções e as rotinas de `config/schedule.yml`.
- **Specs de armazenamento real** (`apps/api/spec/integration/object_storage_spec.rb`, tag `:object_storage`) precisam do SeaweedFS no ar.
- **Dataset de avaliação:** as imagens ficam fora do repositório. `ruby evaluation/fetch.rb` as baixa para `$EVALUATION_IMAGES_DIR` (padrão `~/.cache/nexora-evaluation`), e `bin/rails runner ../../evaluation/run.rb CATALOG_ONLY=1` mede só a correspondência com o catálogo, sem provedor e sem rede. A rodada com provedor exige chaves e fica fora da suíte comum. Passo a passo e limites em [evaluation/README.md](../../evaluation/README.md).
- **Verificações de linguagem:** `python3 scripts/check_language.py` confere os textos estáticos contra a lista proibida, e `bash scripts/test-check-language.sh` prova que o verificador detecta os defeitos. Ambos rodam no CI ([HEALTH_DATA_SAFETY.md](../security/HEALTH_DATA_SAFETY.md)).

### Identidade na Fase 02

- **E-mails:** em desenvolvimento a API grava os e-mails (recuperação de senha) como arquivos em `apps/api/tmp/mails`, sem enviar nada. Abra o arquivo mais recente para pegar o link. O provedor real de e-mail é escolhido no M1.
- **Sidekiq é necessário** para a entrega de eventos da outbox (`user.registered` cria o perfil, `consent.revoked` apaga dados de saúde) e para a exclusão de conta. Sem ele, o perfil fica em `409 profile_pending` e nada é entregue. O agendador (`sidekiq-cron`) sobe junto com o worker.
- **Web:** o Vite encaminha `/api` para `http://localhost:3010`, então o navegador fala só com `http://localhost:5173` e o cookie `__Host-session` fica de primeira parte. Use o Node do `.nvmrc` (26.13.0, `nvm use`).
- **Mobile:** `EXPO_PUBLIC_API_URL` aponta para a API. `EXPO_PUBLIC_APP_WEB_URL` (opcional) é a URL do painel web, usada no link "exportar pelo site" das Configurações; sem ela o app mostra só o texto.
- **Chaves:** em desenvolvimento e teste, as chaves de cifragem e `AUDIT_IP_HMAC_KEY` têm valores públicos locais. Em produção são obrigatórias, com 32 caracteres ou mais ([ADR 0018](../architecture/decisions/0018-application-level-encryption.md)).

## Conferir

```bash
curl -i localhost:3010/health/live     # 200: o processo responde
curl -i localhost:3010/health/ready    # 200: PostgreSQL e Valkey prontos

# Um job atravessa a fila até o Sidekiq. Use o id devolvido no primeiro comando.
curl -s -X POST localhost:3010/internal/smoke_jobs
curl -s localhost:3010/internal/smoke_jobs/<id>    # {"status":"done"}
```

As rotas `/internal` existem só em desenvolvimento e teste.

## Mobile no WSL 2

**Caminho testado: emulador Android no Windows, com Expo Go.** O emulador alcança o IP do WSL pela rede do Windows, sem `adb reverse` nem túnel.

```bash
# No WSL, para descobrir o IP. Ele muda quando o WSL reinicia.
ip -4 addr show eth0 | grep inet

# Metro, com a API e o Metro apontando para esse IP.
cd apps/mobile
REACT_NATIVE_PACKAGER_HOSTNAME=<ip> EXPO_PUBLIC_API_URL=http://<ip>:3010 npx expo start --go
```

No emulador, com o Expo Go da versão do SDK 58 instalado, abra `exp://<ip>:8081`. Pelo WSL:

```bash
adb.exe shell am start -a android.intent.action.VIEW -d exp://<ip>:8081 host.exp.exponent
```

Na primeira abertura, o Expo Go mostra o menu de desenvolvedor sobre o app. Basta fechá-lo.

**Aparelho físico:** não foi testado. Um aparelho na rede local não alcança o IP interno do WSL 2. Seria preciso usar o modo de rede espelhado do WSL ou redirecionar as portas no Windows.

**Limite do Expo Go:** é um ambiente de testes. O build para distribuição fica para o M1.

## Testes, lint e tipos

```bash
# API, com os serviços de apoio no ar
cd apps/api
bundle exec rspec
bundle exec rubocop
bundle exec brakeman -q --no-pager -w2
bundle exec bundle-audit check --update

# Web, mobile e contrato, a partir da raiz
npm run typecheck -w apps/web && npm run lint -w apps/web && npm test -w apps/web && npm run build -w apps/web
npm run typecheck -w apps/mobile && npm run lint -w apps/mobile && npm test -w apps/mobile
npm run check -w @app/contracts
python3 scripts/check_language.py && bash scripts/test-check-language.sh
npm audit --audit-level=high
```

**Ao mudar o contrato:** edite `packages/contracts/openapi.yaml`, rode `npm run generate -w @app/contracts`, e versione o arquivo gerado.

## Variáveis de ambiente

Lista em [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md). No desenvolvimento, todas são opcionais, salvo `EXPO_PUBLIC_API_URL` no mobile. Para ativar o monitoramento, defina os DSNs no ambiente do processo, nunca em arquivo versionado.

**`.env.example`:** a regra `Read(**/.env.*)` em `.claude/settings.json` bloqueia as ferramentas de arquivo do Claude Code, inclusive a escrita. Para alterar esse arquivo, o responsável edita, ou o Claude pede autorização para ajustar a regra.

## Harness

```bash
bash scripts/verify-harness.sh        # Verifica o harness; retorna diferente de zero em falha
bash scripts/test-verify-harness.sh   # Prova que o verificador detecta os defeitos dos cenários
```

## Superpowers

`.claude/settings.json` habilita o plugin, mas isso **não o baixa** em uma máquina nova. Rode uma vez:

```bash
claude plugin install superpowers@claude-plugins-official --scope project
```

Depois, execute `/reload-plugins` no Claude Code ou abra uma nova sessão, e confirme com `claude plugin list`. Versão validada: 7.0.0. Se a versão instalada for outra, leia as instruções atuais de cada skill antes de assumir que nada mudou.

## Observações

- Mantenha o repositório no sistema de arquivos Linux. Arquivos editados pelo Windows podem ter fim de linha CRLF, que o verificador aceita nos documentos. Os scripts precisam de LF, garantido por `.gitattributes`.
- As portas padrão do PostgreSQL e da API foram evitadas porque outros projetos as usam nesta máquina.
- O diretório `.superpowers/` é espaço de trabalho temporário, ignorado pelo Git.
- O `npm` 11 pode avisar sobre scripts de instalação não aprovados, como o do `@sentry/cli`. Nada na fase depende deles.
