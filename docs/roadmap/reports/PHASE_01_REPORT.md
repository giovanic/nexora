# Relatório da Fase 01 — Foundation & Developer Experience

- **Data:** 2026-11-11
- **Estado:** `Em revisão`, aguardando aprovação do responsável
- **Branch:** `phase/01-foundation`, PR #2, sem merge

## 1. Resumo

O esqueleto do monorepo funciona de ponta a ponta, sem funcionalidade de negócio:

- **API Rails 8.1 em Ruby 4.0.9:** PostgreSQL 18, Valkey e Sidekiq, `/health/live` e `/health/ready`, erro central, logs JSON com correlação da requisição ao job, e Sentry sem dados pessoais.
- **Limites de domínio:** verificados por um teste próprio.
- **Contrato OpenAPI:** validado contra as respostas e contra as rotas, por método e caminho, com tipos gerados para web e mobile.
- **Clientes:** web em React com Vite, e mobile em Expo SDK 58, que mostram o estado da API.
- **CI:** seis jobs reais no GitHub Actions. A `main` está protegida e exige esses seis jobs.

## 2. Validação

| Comando | Código | Resultado |
|---|---|---|
| `bundle exec rspec` | 0 | 159 exemplos, 0 falhas |
| `bundle exec rubocop` | 0 | 62 arquivos, sem ofensas |
| `bundle exec brakeman -q --no-pager -w2` | 0 | Nenhum aviso |
| `bundle exec bundle-audit check --update` | 0 | Nenhuma vulnerabilidade |
| Web: typecheck, lint, testes, build | 0 | Todos aprovados |
| Mobile: typecheck, lint, testes | 0 | Todos aprovados |
| `npm run check -w @app/contracts` | 0 | Tipos gerados conferem |
| `npm audit --audit-level=high` | 0 | Nenhum alerta alto ou crítico; 33 moderados e 1 baixo em ferramentas de desenvolvimento |
| `bash scripts/verify-harness.sh` | 0 | Aprovado |
| `bash scripts/test-verify-harness.sh` | 0 | 92 testes, 0 falhas |
| Clone limpo seguindo [LOCAL_DEVELOPMENT.md](../../operations/LOCAL_DEVELOPMENT.md) | 0 | live 200, ready 200, job `done`, web 200, Expo no ar ([log](evidence/phase-01/clean-clone-2026-11-11.log)) |
| CI no commit final `c71db2e` | n/a | 6 de 6 jobs verdes ([execução 43130059847](https://github.com/giovanic/nexora/actions/runs/43130059847)) |

**Prova de que o CI reprova:** um PR por defeito, com o resultado lido pela API do GitHub.

| PR | Defeito | Reprovou |
|---|---|---|
| #3 a #6 | Teste, lint, segurança e limite de domínio na API | `api` |
| #7 | Contrato alterado sem mudar o código | `contracts` e `api` |
| #8 a #10 | Teste, lint e tipos na web | `web` |
| #11, #13 | Teste e tipos no mobile | `mobile` |
| #12 | Variável não usada no mobile | **Não reprovou.** Era só aviso; o CI passou a usar `--max-warnings 0`, provado no #16 |
| #14 | Documento de fase removido | `harness` |
| #15 | Segredo falso de 40 hexadecimais | `secrets` |
| #16 | Variável não usada no mobile, com o CI corrigido | `mobile` |

Nos PRs #8 a #14, o job `secrets` também falhou. A causa foi a branch do #15, que o Gitleaks varre em todas as branches, e não o defeito de cada PR.

## 3. Critérios

| Critério | Evidência | Situação |
|---|---|---|
| `AC-01-01` | Clone limpo; app renderizado no emulador Android em 2026-11-07 ([capturas](evidence/phase-01/)) | Comprovado. Aparelho físico não testado |
| `AC-01-02` | `health_ready_spec.rb`; demonstração com cada serviço parado registrada no ledger | Comprovado por teste. Demonstração sem artefato |
| `AC-01-03` | `smoke_job_spec.rb` com processo Sidekiq real; job `done` no clone limpo | Comprovado |
| `AC-01-04` | Testes de componente e capturas da web e do mobile | Comprovado |
| `AC-01-05` | Tabela de PRs acima | Comprovado |
| `AC-01-06` | PR #15 reprovou `secrets`; PR #5 reprovou a análise de segurança | Comprovado |
| `AC-01-07` | `logging_spec.rb`, `sentry_spec.rb` e testes de monitoramento dos clientes | **Parcial:** sem envio real ao Sentry, por sua decisão de 2026-11-11 |
| `AC-01-08` | `health_spec.rb` e `health_ready_spec.rb` | Comprovado |
| `AC-01-09` | Violação plantada local e PR #6 | Comprovado |
| `AC-01-10` | ADRs 0002, 0003 e 0014 `Aceita`; fila da ADR 0004 decidida | Comprovado |

## 4. Revisões

Rodaram os cinco revisores do projeto sobre a branch inteira. Achados críticos: nenhum.

| Agente | Importantes e tratamento |
|---|---|
| `software-architect` | A verificação de limites só olhava 4 pastas de `app/`, e agora olha toda pasta fora de `app/domains` e também `lib/`. O teste de rotas comparava só caminhos, e agora compara método e caminho, com `:id` convertido em `{id}`. Ambos corrigidos com teste que falhou antes. Textos desatualizados nas ADRs 0002, 0003 e 0014 e no documento da fase foram corrigidos |
| `backend-reviewer` | O pool de conexões podia ficar menor que a concorrência do Sidekiq. Corrigido com teste: o pool usa o maior valor. O código do erro 422 virou `validation_failed`, como na API documentada |
| `security-reviewer` | Brakeman filtrava por confiança alta: agora usa `-w2`, sem avisos. `LOG_LEVEL=DEBUG` em maiúsculas ativava debug em produção: corrigido com teste. **A proteção da `main` não vale para o administrador:** decisão sua, abaixo |
| `qa-reviewer` | As provas de CI tinham ruído: detalhado na tabela de PRs |
| `frontend-mobile-reviewer` | Só achados menores |

**Adiados, de menor gravidade:**

- **Clientes:** 503 sem causa visível; URL ausente confundida com falha de rede; valores do contrato repetidos à mão; modo escuro no mobile.
- **Dados:** mensagens de exceção e argumentos de jobs guardados no Valkey sem política de retenção. Precisa de decisão antes do primeiro job real.
- **CI:** checagens exigidas só pelo nome; token persistido no checkout; sem Dependabot nem execução agendada; versões fixadas sem registro na fonte.
- **Exposição:** e-mail pessoal em dois documentos e no histórico dos commits.

## 5. Verificado e apenas criado

- **Verificado por execução:** todos os comandos da seção 2, o clone limpo, os 14 PRs de defeito e a proteção da `main`, lida de volta pela API.
- **Verificado só no emulador:** o app mobile. Aparelho físico não testado.
- **Apenas criado:** o envio ao Sentry, que foi testado com transporte simulado, nunca com o serviço real.

## 6. Pendências

**Decisões suas**

1. Ligar `enforce_admins` na proteção da `main`. Hoje você, como administrador, consegue enviar direto para a `main` sem os seis jobs. Recomendo ligar.
2. Integrar o PR #2 na `main` depois de aprovar a fase.
3. Dependabot e verificação semanal de segredos e dependências.
4. Progress & Analytics perdeu acesso às APIs de Food AI e Strava Integration, para proteger a regra de que dados do Strava não vão para a IA. Se a Fase 08 precisar, terá de ampliar com justificativa.

**Antes do M1**

- Demonstração real do Sentry e revisão jurídica do Sentry como operador.
- Política de retenção dos logs e dos dados de jobs no Valkey.
- `config.hosts`, SSL e validação de variáveis de produção.

**Sem `.env.example`**, por sua decisão: a lista de variáveis está em [ENVIRONMENT_VARIABLES.md](../../operations/ENVIRONMENT_VARIABLES.md).

## 7. Próximo passo

Para aprovar e iniciar a próxima fase, envie:

> Aprovo a Fase 01. Vamos iniciar a fase 02.

Diga também se quer `enforce_admins` ligado e o PR #2 integrado.
