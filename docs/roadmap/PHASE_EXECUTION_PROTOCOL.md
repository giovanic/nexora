# Protocolo de execução de fases

Obrigatório em todas as sessões. Vale para qualquer linha: fase, etapa ou o marco M1. As skills `phase-kickoff` e `phase-closeout` conduzem o início e o fim. O Superpowers conduz o meio.

## Superpowers é obrigatório

As skills abaixo são as encontradas na versão **7.0.0**. Identifique a instalação antes de começar. **Se o plugin não estiver disponível, informe o bloqueio e o comando de instalação. Nunca simule uma skill nem diga que a usou.**

```bash
claude plugin install superpowers@claude-plugins-official --scope project
```

Depois, é preciso executar `/reload-plugins` ou abrir uma nova sessão.

| Quando | Skill |
|---|---|
| Início de qualquer conversa | `superpowers:using-superpowers` |
| Questões de design em aberto | `superpowers:brainstorming` |
| Plano da fase | `superpowers:writing-plans` |
| Isolar o trabalho | `superpowers:using-git-worktrees` |
| Todo código de produto | `superpowers:test-driven-development` |
| Executar plano com subagent por tarefa | `superpowers:subagent-driven-development` |
| Executar plano na própria sessão | `superpowers:executing-plans` |
| Tarefas independentes em paralelo | `superpowers:dispatching-parallel-agents` |
| Bug, falha ou comportamento inesperado | `superpowers:systematic-debugging` |
| Pedir revisão | `superpowers:requesting-code-review` |
| Receber revisão | `superpowers:receiving-code-review` |
| Antes de afirmar que algo está pronto | `superpowers:verification-before-completion` |
| Integrar a branch | `superpowers:finishing-a-development-branch` |
| Criar ou editar skill do projeto | `superpowers:writing-skills` |

Leia sempre a versão atual. O conteúdo das skills não é copiado para este repositório.

## 1. Início ("Vamos iniciar a fase NN")

Conduzido por [`phase-kickoff`](../../.claude/skills/phase-kickoff/SKILL.md), que também trata a retomada de uma linha já em andamento.

1. Ler `CLAUDE.md`.
2. Consultar as rules pertinentes.
3. Ler [ROADMAP.md](ROADMAP.md) e [STATUS.md](STATUS.md).
4. Ler o documento completo da fase.
5. Consultar as ADRs relacionadas, e o registro de fontes.
6. **Verificar dependências por evidência**: linha `Concluída` com evidência e relatório em `docs/roadmap/reports/`, além da conferência no repositório.
7. Verificar o estado real do repositório: branch, alterações pendentes, testes da última fase.
8. Carregar as skills do Superpowers.
9. Consultar de novo as fontes externas de que a fase depende.
10. Usar `brainstorming` nas questões ainda abertas, **sem repetir o que já foi respondido na documentação**.
11. Gerar o plano com `writing-plans`, salvo em `docs/superpowers/plans/`, ligando cada tarefa aos requisitos e critérios `AC-`.
12. Definir os testes e critérios de aceite do plano.
13. **Apresentar o plano e esperar a aprovação.** Só então a implementação começa.

**Se uma dependência não estiver comprovada:** pare e relate o que falta. Não presuma que uma fase está pronta porque foi declarada concluída. Só o responsável pode autorizar seguir assim, e isso fica registrado como risco.

## 2. Implementação

- **TDD:** RED, GREEN, REFACTOR, sem exceção para código de produto.
- **Isolamento:** `using-git-worktrees`. Um worktree exige ao menos um commit: o primeiro commit do repositório é decisão do responsável, antes da Fase 01.
- **Commits:** pequenos, e **somente quando autorizados**.
- **Revisões frequentes,** com os agentes do projeto.
- **Separação de responsabilidades,** conforme as rules.
- **Tratamento de erros e testes de regressão.**
- **Documentação atualizada junto com o código.**
- **Mudança arquitetural:** ADR antes do código.
- **Dependência nova:** justificativa no plano.
- **Bug:** `systematic-debugging` antes de qualquer correção.

### Subagents

Use quando houver benefício concreto.

- Cada subagent tem responsabilidade específica e recebe contexto suficiente.
- Para execução, `subagent-driven-development`, com revisão de conformidade e de qualidade.
- Não delegue tarefas conflitantes sobre os mesmos arquivos sem coordenar.

| Agente | Quando |
|---|---|
| `software-architect` | Novo contexto, dependência entre domínios, nova ADR, encerramento de fase |
| `backend-reviewer` | Mudanças em `apps/api` |
| `frontend-mobile-reviewer` | Mudanças em `apps/web`, `apps/mobile` |
| `security-reviewer` | Autenticação, dados pessoais, integrações, uploads, texto de saúde |
| `qa-reviewer` | Plano de testes, critérios de aceite, encerramento de fase |

Revisores apontam problemas e não alteram arquivos. Nenhum agente declara uma fase concluída.

### Limites que nunca se negociam por conta própria

Exigem decisão do responsável, registrada em ADR:

- Meta ou teto de calorias, ou pontuação baseada em corpo, calorias ou volume.
- Dados do Strava visíveis a outra pessoa ou enviados à IA.
- Uso da TBCA ou da TACO sem licença verificada.
- Suporte a menores de idade.
- Conteúdo de saúde em logs.
- Ranking, cobrança, ou qualquer item marcado como fora do roadmap.

## 3. Encerramento

Conduzido por [`phase-closeout`](../../.claude/skills/phase-closeout/SKILL.md). Checklist em [DEFINITION_OF_DONE.md](../engineering/DEFINITION_OF_DONE.md).

1. Executar os testes.
2. Executar lint.
3. Executar verificações de tipos.
4. Verificar a segurança aplicável.
5. Revisar arquitetura.
6. Revisar requisitos: cada `AC-` com evidência.
7. Executar `verification-before-completion`.
8. Atualizar documentação.
9. Atualizar [ROADMAP.md](ROADMAP.md) e [TRACEABILITY.md](TRACEABILITY.md).
10. Usar `requesting-code-review`, antes do relatório, e tratar os achados.
11. Produzir o relatório em `docs/roadmap/reports/` e atualizar [STATUS.md](STATUS.md).
12. Apresentar o relatório, e **parar**. Depois, usar `finishing-a-development-branch` conforme a decisão do responsável.

Nenhuma fase é concluída só porque os arquivos foram criados. Testes falhando não permitem encerrar, mesmo sob pressão de prazo.

**A linha fica em `Em revisão` até a aprovação do responsável.** Só então passa a `Concluída`. O Claude nunca avança sozinho para a próxima fase.

## 4. Controle de estado

Em [STATUS.md](STATUS.md). Cada mudança acrescenta uma linha ao registro, com data e evidência, e atualiza a tabela.

| Estado | Quando |
|---|---|
| `Não iniciada` | Estado inicial |
| `Em planejamento` | Responsável autorizou; plano sendo escrito |
| `Em desenvolvimento` | Plano aprovado; implementação em andamento |
| `Em revisão` | Implementação pronta; aguardando revisão e aprovação |
| `Bloqueada` | Impedida por algo externo, com o motivo como evidência |
| `Concluída` | Aprovada pelo responsável, com evidência |

- Só uma linha pode estar `Em desenvolvimento` por vez, porque há um único desenvolvedor. A linha `05` é apenas um resumo, e não conta para essa regra.
- `05` passa a `Em desenvolvimento` ao iniciar `05.1`, e a `Concluída` somente quando `05.1` e `05.2` estiverem concluídas. As skills fazem isso.
- `Concluída` só vem de `Em revisão`, e exige relatório. Defeito achado depois pode reabrir a linha para `Em desenvolvimento`, com evidência e autorização do responsável.
- Evidência é um link ou uma referência concreta: relatório, plano aprovado, mensagem do responsável com data.

## 5. Rastreabilidade

```text
Requisito (FUNCTIONAL_REQUIREMENTS.md)
  → Decisão (ADR, quando houver decisão arquitetural)
  → Fase (documento da fase)
  → Tarefa (plano em docs/superpowers/plans/)
  → Implementação e teste (TRACEABILITY.md, preenchido no encerramento)
  → Critério de aceite (AC- no documento da fase)
```

A matriz é preenchida no encerramento, não a cada tarefa. Assim a cadeia completa existe sem manutenção diária.

## 6. Fontes externas

Quando uma decisão depende de informação externa ou de versão:

1. Consultar a documentação oficial.
2. Confirmar a versão atual.
3. Verificar compatibilidade.
4. Registrar fonte e data no [registro de fontes](../architecture/EXTERNAL_SOURCES.md).
5. Não inventar capacidades de APIs ou bibliotecas. Item não verificado continua marcado como tal.

## 7. Contratos de formato

O `scripts/verify-harness.sh` impõe estes formatos, sem julgar se o conteúdo é bom: isso cabe às revisões.

**Linhas:** `00`–`09`, `05.1`, `05.2`, `M1`.

**Documento de fase:** títulos `##` nesta ordem: Objetivo; Escopo; Funcionalidades; Dependências; Arquivos e módulos esperados; Critérios de aceite; Testes; Riscos; Entregáveis; Definition of Done; Estratégia de revisão. Modelo em [PHASE_TEMPLATE.md](PHASE_TEMPLATE.md).

**Critério de aceite:** `AC-<linha>-NN`, como `AC-03-01` ou `AC-05.1-02`. Cada um diz como é comprovado.

**Requisito:** definido só em [FUNCTIONAL_REQUIREMENTS.md](../product/FUNCTIONAL_REQUIREMENTS.md), em linha de tabela iniciada por `| FR-<DOMÍNIO>-NNN |` ou `| NFR-<TIPO>-NNN |`.

**Matriz:** `| Requisito | Fase | ADR | Implementação | Teste | Critério de aceite |`. Célula vazia é `—`.

**Status:** seção `## Estado atual` com `| Linha | Estado | Desde | Evidência |`, e seção `## Registro de transições` com `| Data | Linha | De | Para | Evidência |`.

**ADR:** `decisions/NNNN-slug.md`, com títulos `##` Contexto; Problema; Alternativas; Decisão; Justificativa; Consequências; Estado da decisão. A primeira linha do estado é `Proposta`, `Aceita`, `Rejeitada` ou `Substituída`.

**Texto inacabado:** `TBD`, `TODO` e `FIXME` só entre crases, em blocos de código ou em modelos. Fora disso, resolva ou registre como risco.

**`CLAUDE.md`:** menos de 200 linhas.
