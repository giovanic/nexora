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

**Já vale:** a stack de referência do Master Prompt como direção, com versões fixadas em arquivo (`.ruby-version`, `.nvmrc` ou `.tool-versions`) e em imagens Docker, e sem depender das versões da máquina.

**Fica para a Fase 01:** as versões exatas, depois de executar uma aplicação mínima com cada combinação candidata, com testes e consulta de novo às fontes.

**Proposta a validar:** Ruby 4.0, com 3.4 como alternativa se a validação falhar; Rails 8.1.x; PostgreSQL 18; Node 22 ou o LTS mais recente aceito pelo Expo; Redis ou Valkey após verificar a licença.

## Justificativa

Fixar versões em papel, sem executar, criaria uma decisão hipotética. A verificação custa pouco na Fase 01.

## Consequências

- A Fase 01 atualiza esta ADR para `Aceita`, com a evidência da verificação.
- Versões usam o container, e não a máquina local.
- O registro de fontes é atualizado.

## Estado da decisão

Proposta
