# Relatório da Fase 00 — Engineering Harness

- **Data:** 2026-11-05
- **Estado:** `Concluída`, por aprovação do responsável em 2026-11-06, aceitando a lacuna do check `scope`
- **Commits:** nenhum durante a execução, como pedido. O commit `873c7a6` foi feito depois deste relatório

## A. Resumo executivo

Foi criado o sistema de engenharia do produto: documentação, regras, agentes revisores, duas skills, controle de estado por evidência e um verificador automático. Uma sessão nova lê o `CLAUDE.md`, descobre o estado em `STATUS.md` e segue o protocolo. Nenhuma fase avança sem autorização do responsável.

Ficou uma pendência de decisão: as pastas `apps/` e `packages/`, geradas fora do processo e mantidas pelo responsável, fazem o verificador reprovar no check `scope`.

## B. Arquitetura

- **Forma:** monólito modular em Rails, monorepo, 12 domínios separados por namespace e comunicação por API pública e eventos com outbox.
- **Food AI:** o modelo identifica alimentos e porções, e o nosso código calcula nutrientes a partir de bases com origem conhecida. Estimativa sempre em faixa.
- **Strava:** o webhook é só gatilho e toda ação é confirmada na API. Dados visíveis só ao dono, sem envio à IA.
- **Gamificação:** só escuta eventos, sem calorias, peso, duração ou distância. Livro-razão à prova de repetição, com tetos e recuperação.
- **Decisões:** 17 ADRs: 5 `Aceita` e 12 `Proposta`, com fase e forma de decisão.

Fluxos principais em [SYSTEM_OVERVIEW.md](../../architecture/SYSTEM_OVERVIEW.md).

## C. Estrutura

```text
CLAUDE.md, README.md, .gitignore, .gitattributes
.claude/   settings.json, rules/ (8), agents/ (5), skills/ (phase-kickoff, phase-closeout)
docs/      product/, architecture/ (com decisions/), security/, engineering/, operations/
           roadmap/ (ROADMAP, STATUS, TRACEABILITY, protocolo, phases/, reports/)
           superpowers/ (specs/, plans/)
scripts/   verify-harness.sh, verify_harness.py, test-verify-harness.sh, harness-manifest.txt
```

## D. Superpowers

Instalado nesta sessão, com autorização: versão 7.0.0, escopo de projeto.

| Skill | Uso real |
|---|---|
| `using-superpowers`, `brainstorming` | Conversa e design aprovado |
| `writing-plans`, `executing-plans` | Plano de 15 tarefas, executado na sessão |
| `test-driven-development` | Verificador, com RED observado antes de cada implementação |
| `writing-skills` | Cenários antes e depois das skills |
| `requesting-code-review`, `receiving-code-review` | Quatro revisores e classificação dos achados |
| `verification-before-completion` | Antes deste relatório |

**Não usadas:** `using-git-worktrees` (exige um commit), `subagent-driven-development` (o responsável aceitou a execução na sessão), `dispatching-parallel-agents` (subagents em paralelo foram despachados sem carregar a skill), `systematic-debugging` (o bug do `NFR-A11Y` foi corrigido sem carregá-la), `finishing-a-development-branch` (depende da sua decisão sobre commits).

Nas próximas fases, `phase-kickoff` e `phase-closeout` conduzem essas skills, conforme o [protocolo](../PHASE_EXECUTION_PROTOCOL.md).

## E. Roadmap

Ordem sugerida: `01 → 02 → 03 → 05.1 → M1 → 04 → 05.2 → 06 → 07 → 08 → 09`. Dependências e critérios em [ROADMAP.md](../ROADMAP.md).

## F. Validação

| Comando | Código | Resultado |
|---|---|---|
| `bash scripts/test-verify-harness.sh` | 0 | 92 testes, 0 falhas |
| Teste de mutação: apagar cada um dos 59 ramos de falha do verificador | n/a | 59 detectados, 0 sobreviventes |
| `bash scripts/verify-harness.sh` | 1 | 2 falhas, só as conhecidas: `scope` em `apps` e `packages` |
| O mesmo verificador numa cópia sem essas pastas | 0 | Aprovado |
| O mesmo na cópia, com um documento de fase removido | 1 | Reprovado, como esperado |

### Critérios

| Critério | Evidência | Situação |
|---|---|---|
| `AC-00-01` | Tabela acima | Comprovado, com a falha admitida |
| `AC-00-02` | Subagent sem contexto acertou as 9 perguntas | Comprovado, antes das correções da revisão |
| `AC-00-03` | Check `status` e cenários das skills | Comprovado, com ressalva abaixo |
| `AC-00-04` | Check `traceability`: 127 requisitos | Comprovado |
| `AC-00-05` | Check `required` e revisões | Comprovado |
| `AC-00-06` | `apps/` e `packages/` vêm de geradores, sem código de negócio | **Parcial:** o check `scope` reprova |
| `AC-00-07` | Seção D | Comprovado |
| `AC-00-08` | Inspeção no início da sessão e seção de revisões | Comprovado |

No Master Prompt, seção 14, o item "o harness passou pela verificação" fica **parcial** pelo mesmo motivo. Os demais estão atendidos.

### Cenários das skills

- **Sem as skills:** 6 de 7 cenários rodaram, sem nenhuma violação das regras, porque o `CLAUDE.md` e o protocolo já as seguravam. O sétimo foi interrompido por salvaguarda da API e ficou sem referência. Portanto, **estes testes não provam que as skills acrescentam disciplina**. Elas padronizam formato e procedimento.
- **Com as skills:** 7 de 7 aprovados, mais 3 retestes depois de ajustes.
- **Limites:** uma repetição por cenário, sem medir variância. As últimas edições em `phase-closeout` (carregar o Superpowers, revisores obrigatórios) não foram retestadas.

### Revisões

Rodaram `software-architect`, `security-reviewer`, `qa-reviewer` e uma revisão final geral, que seguiu no Opus porque os créditos do Fable acabaram. Os achados foram tratados em uma rodada, sem nova revisão, como a skill prevê. **Os documentos corrigidos não foram relidos por um revisor independente.**

| Corrigidos, entre os principais | Onde |
|---|---|
| Webhook forjado apagando dados de terceiros | Strava, `AC-04-11` |
| Revogação de consentimento sem efeito na maioria dos contextos | LGPD, `AC-02-07`, `AC-04-09` |
| Conteúdo da refeição sobrevivendo à exclusão | Banco, `AC-03-05` |
| Ciclo entre as Fases 07 e 08, com Notifications movida para a 08 | Fases, requisitos |
| Duração chegando à gamificação; XP premiando registro repetido e treino em dia de recuperação | Domínio, gamificação, `AC-06-07`, `AC-06-09` |
| Retomada de fase inexistente | `phase-kickoff` |
| Verificador aceitando evidência falsa ou caminhos inexistentes | Verificador e testes |
| Revisão de saúde só depois do beta | `AC-M1-11` |

### Verificado e apenas criado

- **Verificado por execução:** scripts, formatos, links, rastreabilidade e estados.
- **Exercitado por subagents:** compreensão do `CLAUDE.md` e as duas skills, em cenários.
- **Apenas criado:** os agentes revisores nunca rodaram contra código real; as regras `deny` só foram vistas funcionando em `rm -rf`, e as demais não foram testadas; toda a arquitetura segue sem validação em código.

## G. Pendências

**Decisões suas**

1. Aprovar esta fase, aceitando a lacuna do check `scope` em `apps/` e `packages/`. **Decidido em 2026-11-06:** aprovada, com a lacuna aceita. O check `scope` segue reprovando nessas pastas enquanto a linha 01 não estiver em desenvolvimento.
2. Decidir o primeiro commit e o repositório remoto, necessários para worktree e CI.
3. Na Fase 01, decidir o que aproveitar das pastas geradas. Elas usam Ruby 3.3.4, Solid Queue e Minitest, em vez de Sidekiq, Redis e RSpec.

**Ações externas**

- Pedir à TBCA autorização de uso comercial (`tbca.contato@usp.br`), antes da Fase 03. Sem ela, o caminho é USDA com composições próprias.
- Revisão jurídica e revisão por profissional de saúde, antes do beta.
- Assinatura do Strava para a Fase 04. Definir a marca antes do lançamento.

**Não verificado**

Licença da TACO, versão e licença do Redis, preços e política de dados da OpenAI, compatibilidade entre Ruby 4 e Rails 8.1, janela de suporte do Expo, e se o termo do Strava alcança dados derivados ([ADR 0017](../../architecture/decisions/0017-derived-data-after-source-removal.md)). Normas citadas por um revisor, de memória, estão nas pendências jurídicas.

**Decisões que tomei durante a execução**

| Decisão | Custo se errada |
|---|---|
| Sem scripts automáticos do Superpowers, com registro de progresso manual | Baixo |
| Sem worktree e sem commits | Nenhum commit para reverter |
| Testes do verificador com árvore gerada | Baixo: há prova na cópia real |
| Skills como receitas, por não haver violação de disciplina na referência | Menor resistência a pressões novas |
| Falha do `scope` documentada, sem lista de exceções, seguindo sua decisão | Lembrar dela a cada verificação até a Fase 01 |
| Novas regras do verificador: relatório obrigatório, `Concluída` só a partir de `Em revisão`, células com caminhos reais | Mais rigor no encerramento |
| Outbox na Fase 02; Notifications na Fase 08; regras de XP em classes, em vez de motor em dados; limites de XP propostos | Reversível por ADR |

**Não adotado ou adiado**

- Hook técnico para restringir `Bash` dos revisores, porque o design descarta hooks nesta fase. Hoje é só instrução.
- Bloqueio de `curl` e `wget`, porque o uso legítimo no desenvolvimento é comum.
- Casos raros de parser: links por referência, âncoras inexistentes, `XXX` e datas absurdas.
- 25 critérios de processo sem requisito próprio não entram na matriz.
- Decisões de e-mail, monitoramento e push, e o armazenamento de desenvolvimento, ficam para a fase que os usar.
- Pequenas lacunas de desenho de banco e API ficam para a fase dona.
- Retomada sem plano existente ainda não está definida em `phase-kickoff`.

## H. Próximo passo

Para aprovar e iniciar a próxima fase, envie:

> Aprovo a Fase 00, aceitando a lacuna do check scope. Vamos iniciar a fase 01.

A Fase 01 não foi iniciada.
