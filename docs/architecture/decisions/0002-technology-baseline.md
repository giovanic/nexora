# 0002 — Baseline de tecnologias e versões

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-OPS-001

## Contexto

O Master Prompt define a stack de referência: Rails API, PostgreSQL, Redis, Sidekiq, React com Vite, Expo, TypeScript, S3 compatível, REST com OpenAPI, Docker e GitHub Actions, "como baseline, não como justificativa para instalar tudo imediatamente".

Consulta de 2026-11-05 ([fontes](../EXTERNAL_SOURCES.md)) e versões nesta máquina:

| Ferramenta | Atual oficial | Nesta máquina |
|---|---|---|
| Ruby | 4.0.9; 3.4 em manutenção normal | 3.3.4, que só recebe segurança até 2027-03-31 |
| Rails | 8.1.4.1; exige Ruby ≥ 3.2; 8.1 com segurança até 2027-10-10 | 8.1.4 |
| Node | LTS 26.13; 22 e 24 também em LTS | 22.18 |
| PostgreSQL | 18.6 | 17.0 |
| Redis | Não verificado | 7.4.1 |
| Sidekiq | 8.1.7; Redis ≥ 7.0 ou Valkey ≥ 7.2 | n/a |
| Expo | SDK 58, React Native 0.88, React 19.3, Node ≥ 22.13 | n/a |
| React / Vite | 19.3 / 8.3.6; Vite exige Node ≥ 20.19 ou ≥ 22.12 | n/a |

## Problema

Quais versões adotar, sem assumir compatibilidade não confirmada?

## Alternativas

**Ruby:**

1. Ruby 4.0: mais recente, mas a compatibilidade com Rails 8.1 e Sidekiq não foi confirmada.
2. Ruby 3.4: em manutenção normal, mais conservador.
3. Ruby 3.3.4 local: já instalado, mas perto do fim de suporte. Descartar para um projeto novo.

**Node:** 22 (já instalado e aceito por Expo e Vite), 24 ou 26. A escolha depende da compatibilidade com Expo SDK 58.

**Redis ou Valkey:** Sidekiq aceita ambos. A licença e a versão do Redis não foram verificadas.

**PostgreSQL:** 18, em container, para o maior suporte (até 2030), ou 17 (já instalado).

## Decisão

A stack de referência do Master Prompt vale como direção, com versões fixadas em `apps/api/.ruby-version`, `.nvmrc`, lockfiles e tags exatas de imagem, sem depender das versões da máquina.

| Item | Versão |
|---|---|
| Ruby | 4.0.9 |
| Rails | 8.1.4.1 |
| Sidekiq | 8.1.7 |
| Node | 26.13 (LTS) |
| PostgreSQL | 18.6 |
| Serviço de fila | Valkey 9.1.3, decisão do responsável em 2026-11-06 |
| Expo | SDK 58 |
| React / Vite | 19.3 / 8.3 |
| TypeScript | 6.0 nos clientes; 5.9 só em `packages/contracts`, porque o `openapi-typescript` declara `^5.x` |
| ESLint | 9.39, a versão que `expo install` resolve para o SDK 58, nos dois clientes |

## Evidência

Aplicação mínima executada em 2026-11-06, em diretório temporário depois apagado, com `postgres:18.6` e `valkey/valkey:9.1.3` em containers.

| Verificação | Resultado |
|---|---|
| `bundle install` em Ruby 4.0.9, com Rails 8.1.4.1, Sidekiq, rspec-rails 8.1.0, openapi_first 4.3.0, lograge, sentry-rails, rack-cors | Código 0 |
| `rails db:prepare`, e `show server_version` | Código 0, `18.6` |
| RSpec com processo `sidekiq` real, processando job no Valkey | Passou; `valkey_version:9.1.3` |
| `openapi_first` com contrato 3.1.1 | Aprova a resposta conforme e reprova a divergente |
| Brakeman `-w3` e `bundle-audit check --update` | Código 0, sem achados |
| Inicialização em produção sem `credentials.yml.enc` | Inicia |
| RuboCop 1.92.2 em Ruby 4.0 | Código 0. Com Packwerk no Gemfile, a resolução trava o RuboCop em 1.74, que recusa Ruby 4.0 |
| Node 26.13: `openapi-typescript` com TypeScript 5.9 | Tipos gerados |
| Node 26.13: `tsc -b`, `vite build`, `npm audit --audit-level=high` na web, com TypeScript 6.0 | Código 0 |
| Node 26.13: `npx expo-doctor` no mobile | 20 de 20 verificações |
| Node 26.13: `eslint` com `typescript-eslint` 8.72 e ESLint 9.39, na web | Código 0 |

O `tsc` do mobile falhou na primeira validação, com erros só em arquivos de demonstração do template. Removidos esses arquivos, `tsc --noEmit` passa com TypeScript 6.0, assim como `npx expo install --check` e `npx expo export --platform android`, com o Metro empacotando dentro dos workspaces do npm.

## Justificativa

Fixar versões em papel, sem executar, criaria uma decisão hipotética. A execução acima substitui a compatibilidade que as fontes não afirmavam, como Rails 8.1 com Ruby 4.0.

Valkey em vez de Redis: as duas opções funcionam com o Sidekiq, e o Redis a partir da versão 8 é RSALv2, SSPLv1 ou AGPLv3, enquanto o Valkey é BSD-3-Clause.

## Consequências

- PostgreSQL e Valkey usam container, e não a versão da máquina local. Ruby e Node são fixados por arquivo.
- O registro de fontes é atualizado.
- **Risco:** o Rails 8.1 só recebe correções de segurança, e até 2027-10-10. Reavaliar quando sair uma nova linha.
- **Risco:** a validação não prova o comportamento em produção nem cobre todas as gems futuras.
- O nome da variável segue `REDIS_URL`, que é o que o Sidekiq lê, mesmo com Valkey.

## Estado da decisão

Aceita
