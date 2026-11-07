# Fase 00 — Engineering Harness

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** NFR-HARNESS-001, NFR-HARNESS-002, NFR-HARNESS-003, NFR-HARNESS-004
- **Fontes:** [design](../../superpowers/specs/2026-11-05-engineering-harness-design.md), [plano](../../superpowers/plans/2026-11-05-engineering-harness.md), [Master Prompt](../../product/MASTER_PROMPT.md)

## Objetivo

Criar o sistema operacional de engenharia: uma sessão nova do Claude Code, sem memória, entende o produto, a arquitetura, o estado do projeto e como executar a próxima etapa, com base só no harness.

## Escopo

**Inclui:** `CLAUDE.md`, rules, skills do projeto, agents, documentação de produto, arquitetura, segurança, engenharia, operações, roadmap, protocolo, verificador e seus testes.

**Não inclui:** qualquer código de produto, migrations, endpoints, `apps/`, `packages/`, `docker-compose.yml`, integração com Strava ou IA, dependências de runtime ou commits.

## Funcionalidades

- `CLAUDE.md` como mapa, com regras invioláveis, em menos de 200 linhas.
- Rules sempre ativas e rules por caminho.
- Skills `phase-kickoff` e `phase-closeout`, testadas por cenários de pressão.
- Cinco agents revisores, sem ferramenta de edição.
- Documentos de todas as fases, com as 11 seções.
- Requisitos com identificadores e matriz de rastreabilidade.
- ADRs iniciais, com estado honesto.
- `STATUS.md` com controle de estado por evidência.
- `verify-harness.sh` com testes que provam a detecção de cada defeito.

## Dependências

- Superpowers instalado: versão 7.0.0, registrada no [registro de fontes](../../architecture/EXTERNAL_SOURCES.md).
- Design e plano aprovados pelo responsável.

## Arquivos e módulos esperados

A lista completa está em `scripts/harness-manifest.txt`.

## Critérios de aceite

Critérios da seção 14 do Master Prompt, agrupados:

- `AC-00-01` (NFR-HARNESS-001): verificador retorna diferente de zero em falha crítica e, no harness real, as únicas falhas admitidas são a falha conhecida do check `scope` por pastas mantidas por decisão do responsável em 2026-11-05. **Comprovado por:** `bash scripts/test-verify-harness.sh`, `bash scripts/verify-harness.sh`, a mesma verificação numa cópia sem essas pastas, e um defeito plantado nela.
- `AC-00-02` (NFR-HARNESS-002): uma sessão nova responde corretamente sobre produto, estado, início de fase, dependências da Fase 03 e restrição do Strava, lendo o que o `CLAUDE.md` indica. **Comprovado por:** subagent sem contexto da conversa, com respostas registradas no relatório.
- `AC-00-03` (NFR-HARNESS-003): `STATUS.md` traz estado, data e evidência, e `phase-kickoff` e `phase-closeout` não avançam sem autorização. **Comprovado por:** check `status` e cenários de pressão das skills.
- `AC-00-04` (NFR-HARNESS-004): todo requisito está coberto por uma fase, com critério de aceite. **Comprovado por:** check `traceability`.
- `AC-00-05`: visão, PRD, arquitetura geral, domínio, banco, Food AI, Strava, gamificação, ADRs, nove fases, protocolo, `CLAUDE.md`, rules, agents e skills existem com conteúdo real. **Comprovado por:** check `required` e revisão por `software-architect`, `security-reviewer` e `qa-reviewer`.
- `AC-00-06`: esta fase não implementou funcionalidade do produto. **Comprovado por:** inspeção de `apps/` e `packages/`, geradas fora do processo e sem código de negócio, e `git status --short`. O check `scope` acusa essas pastas, e isso segue como pendência de decisão do responsável.
- `AC-00-07`: o Superpowers foi identificado e efetivamente utilizado. **Comprovado por:** relatório da fase, listando as skills invocadas e o que elas produziram.
- `AC-00-08`: o repositório foi inspecionado antes de criar arquivos, e toda a documentação passou por revisão independente. **Comprovado por:** seções do relatório com a inspeção inicial e os achados de cada revisor, com o tratamento dado.

## Testes

- `scripts/test-verify-harness.sh`: um cenário por defeito, incluindo caminhos com espaços, CRLF e falsos positivos.
- Cenários de pressão das skills, feitos com `superpowers:writing-skills`.
- Teste de sessão nova.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Documentação grande demais para manter | Harness abandonado | `CLAUDE.md` curto, rules por caminho e matriz atualizada só no encerramento |
| Fatos externos envelhecem | Decisões erradas | Registro de fontes com data, e nova consulta no início de cada fase |
| Decisão hipotética parecer definitiva | Fases seguintes presas a um palpite | ADRs em `Proposta`, com critério de validação |
| Plugin ausente em outra máquina | Fluxo simulado | Instrução de bloqueio no `CLAUDE.md` |

## Entregáveis

Todos os arquivos do manifesto e o [relatório da fase](../reports/PHASE_00_REPORT.md).

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), adaptada: sem testes de produto, lint de aplicação nem tipos, porque não há aplicações. A evidência é o verificador, os testes, as revisões e a aprovação do responsável.

## Estratégia de revisão

`software-architect` (coerência), `security-reviewer` (privacidade e permissões) e `qa-reviewer` (critérios verificáveis). O responsável aprova o relatório e autoriza o passo seguinte.
