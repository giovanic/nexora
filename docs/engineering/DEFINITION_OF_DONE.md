# Definition of Done

Regra geral: **sem evidência verificável, não está pronto.** Arquivo criado não é prova.

## Tarefa

- [ ] Critério de aceite vinculado à tarefa no plano da fase.
- [ ] Teste escrito antes do código e visto falhando, quando aplicável.
- [ ] Testes da tarefa e suíte da aplicação executados e lidos.
- [ ] Lint e tipos aprovados.
- [ ] Sem segredo, dado sensível em log ou dependência sem justificativa.
- [ ] Sem `TODO` crítico sem responsável.
- [ ] Documentação afetada atualizada.
- [ ] Commit somente se autorizado.

## Fase

As verificações da seção 7.3 do [Master Prompt](../product/MASTER_PROMPT.md), conduzidas pela skill `phase-closeout`:

- [ ] Testes de todas as aplicações executados.
- [ ] Lint executado.
- [ ] Verificação de tipos executada.
- [ ] Segurança verificada: Brakeman, auditorias e `security-reviewer`, quando aplicável.
- [ ] Arquitetura revisada pelo `software-architect`, e critérios pelo `qa-reviewer`, em toda fase.
- [ ] Requisitos revisados: todo `AC-` da fase com evidência.
- [ ] `superpowers:requesting-code-review` e tratamento com `superpowers:receiving-code-review`.
- [ ] `superpowers:verification-before-completion` executada.
- [ ] `scripts/verify-harness.sh` aprovado, salvo falha conhecida registrada no `CLAUDE.md`.
- [ ] `TRACEABILITY.md` preenchido com implementação e teste.
- [ ] ADRs da fase com estado atualizado, e registro de fontes atualizado.
- [ ] Documentação e roadmap atualizados.
- [ ] Relatório em `docs/roadmap/reports/`, como `PHASE_03_REPORT.md`, `PHASE_05.1_REPORT.md` ou `M1_REPORT.md`.
- [ ] `superpowers:finishing-a-development-branch` conforme a decisão do responsável.
- [ ] Aprovação do responsável registrada em `STATUS.md`, com data e evidência.

**A fase seguinte não começa sem autorização do responsável.**

## Formato de evidência

| Tipo | Registrar |
|---|---|
| Comando | Comando exato, código de saída e resumo do resultado, como `bundle exec rspec`, `0`, `412 examples, 0 failures` |
| Tela | Captura ou gravação, além do teste automático |
| Integração real | Data, ambiente e o que foi observado, sem dados pessoais nem tokens |
| Revisão | Agente ou pessoa, achados e como cada um foi tratado |
| Decisão externa | Fonte, data e quem decidiu |

Separe o que foi **verificado** do que foi apenas **criado**. Se algo não foi executado, diga isso.

## Beta e lançamento

Os checklists estão em [RELEASE_CHECKLIST.md](../operations/RELEASE_CHECKLIST.md).
