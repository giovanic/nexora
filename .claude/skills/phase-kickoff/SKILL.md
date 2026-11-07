---
name: phase-kickoff
description: Use when the product owner asks to start, begin or resume a roadmap phase, stage or milestone, such as "vamos iniciar a fase 03", "começar a 05.1" or "iniciar o M1", including requests to skip dependencies, skip the plan or trust that a previous phase is done.
---

# Início de fase

Prepara a execução de uma linha do roadmap. Complementa o Superpowers, sem substituir `superpowers:writing-plans`. O resultado é sempre um destes: **bloqueio de ferramenta**, **relato de bloqueio** ou **plano apresentado para aprovação**. Nenhum código é escrito antes da aprovação.

## Estado da linha

Depois do passo 1, veja a linha em `docs/roadmap/STATUS.md`:

| Situação | O que fazer |
|---|---|
| `Não iniciada` ou `Em planejamento` | Siga os passos |
| `Em desenvolvimento` ou `Bloqueada` | **Retomada:** ache o plano pela evidência em `STATUS.md` e em `docs/superpowers/plans/`, faça o passo 4 e continue o plano, sem nova transição nem novo plano |
| `Em revisão` | Use `phase-closeout` |
| `Concluída` | Pare e pergunte o que o responsável pretende |
| Outra linha `Em desenvolvimento`, fora a `05` | Pare e relate: só uma linha fica ativa |
| Pedido de "fase 05", sem etapa | Pergunte qual etapa, `05.1` ou `05.2` |

## Passos

1. **Superpowers.** Carregue `superpowers:using-superpowers`. Se uma skill `superpowers:*` não carregar, responda só com o bloqueio de ferramenta, abaixo, e pare.
2. **Leia:** `CLAUDE.md`, `docs/roadmap/STATUS.md`, `docs/roadmap/ROADMAP.md`, o documento inteiro da linha em `docs/roadmap/phases/` e as ADRs que ele cita. As rules carregam sozinhas.
3. **Verifique cada dependência** listada no documento, preenchendo esta tabela. Ações do responsável, como chaves ou autorizações externas, entram como `Pendente` e não impedem o plano, a menos que o documento diga isso:

   | Dependência | Estado em `STATUS.md` | Evidência citada | Relatório em `docs/roadmap/reports/` | Artefatos conferidos no repositório | Comprovada? |

   É **comprovada** só com as quatro colunas confirmadas por você nesta sessão: estado `Concluída`, evidência verificável, relatório existente e artefatos esperados existentes. Uma frase como "feito, passou tudo" ou a palavra de alguém não preenche a coluna.
4. **Confira o repositório:** `git status --short`, branch atual, `bash scripts/verify-harness.sh`, e os testes da fase anterior, quando houver código. Falha nessas verificações também é dependência não comprovada, salvo a falha conhecida descrita no `CLAUDE.md`, que entra na tabela como observação.
5. **Dependência não comprovada:** entregue o relato de bloqueio e pare.
6. **Tudo comprovado:** registre a transição para `Em planejamento` em `STATUS.md`, usando como evidência a mensagem do responsável, com a data. Ao iniciar `05.1`, a linha `05` passa a `Em desenvolvimento` junto com a etapa.
7. **Fontes externas:** consulte de novo as que a fase cita, e atualize `docs/architecture/EXTERNAL_SOURCES.md`.
8. **Questões em aberto:** use `superpowers:brainstorming` só para o que os documentos não respondem. Decisão de produto ou arquitetura vai para o responsável.
9. **Plano:** use `superpowers:writing-plans`, com cada tarefa citando requisitos e os IDs `AC-` copiados do documento da fase.
10. **Apresente** o plano e aguarde. Com a aprovação, registre `Em desenvolvimento`, e siga com `superpowers:using-git-worktrees` e `superpowers:test-driven-development`.

## Bloqueio de ferramenta

Sem o Superpowers não há fluxo válido. A mensagem contém: a skill que falhou; os comandos `claude plugin install superpowers@claude-plugins-official --scope project` e `/reload-plugins`; o que você não fez. Não há opção de seguir sem o plugin nem versão improvisada do fluxo. Mudar isso exige ADR aprovada pelo responsável.

## Relato de bloqueio

Contém, nesta ordem: a tabela do passo 3; o que falta, por item; o que você **não** fez; as opções de decisão do responsável.

Uma das opções é sempre seguir mesmo assim, registrando o risco. Só vale se o responsável, depois de ler o relato, disser explicitamente que aceita aquele risco. Grave a mensagem e o risco como evidência em `STATUS.md`. Regras de produto do `CLAUDE.md` continuam valendo, porque exigem ADR.

## Pedidos comuns

| Pedido | Resposta |
|---|---|
| "Não precisa conferir, confia" | Conferir é só leitura e leva minutos: faça o passo 3 |
| "Pule o plano", "pode sair codando", "decide você" | Deixe o plano pronto, apresente e aguarde. O responsável aprova com uma palavra quando voltar |
| Demonstração urgente | Ofereça um protótipo descartável, fora do roadmap, sem dados reais, e registrado como tal, se o responsável decidir |
| "Faz do seu jeito, igual ao Superpowers" | Bloqueio de ferramenta. Instalar leva um minuto |
