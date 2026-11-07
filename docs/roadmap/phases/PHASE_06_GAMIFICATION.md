# Fase 06 — Gamification Engine

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** FR-GAME-001, FR-GAME-002, FR-GAME-003, FR-GAME-004, FR-GAME-005, FR-GAME-006, FR-GAME-007, FR-GAME-008, FR-GAME-009, FR-GAME-010, FR-GAME-011, FR-GAME-012, FR-GAME-013, NFR-SAFETY-002
- **ADRs:** [0004](../../architecture/decisions/0004-domain-events-transactional-outbox.md), [0009](../../architecture/decisions/0009-gamification-safety-principles.md), [0013](../../architecture/decisions/0013-sport-ranking.md)
- **Arquitetura:** [GAMIFICATION_ARCHITECTURE.md](../../architecture/GAMIFICATION_ARCHITECTURE.md)

## Objetivo

Eventos legítimos geram progressão auditável, sem concessão duplicada, e premiando somente constância, cuidado e recuperação, de forma justa entre níveis de experiência.

## Escopo

**Inclui:** contextos Gamification e Missions; regras; livro-razão; níveis; missões por esporte e nível; conquistas; sequências; desafios; recompensas virtuais; histórico; retorno visual no mobile.

**Não inclui:** ranking, comparação com outras pessoas, cobrança, ou qualquer critério proibido. O painel web completo fica na Fase 07.

## Funcionalidades

- **Registro de regras** em classes Ruby versionadas, com um objeto de fatos de lista fechada.
- **`AwardXp`:** transação com `consumed_events` e índice único.
- **Tetos** diários e semanais para XP de atividade.
- **Estorno** com lançamento negativo, sem apagar histórico.
- **Níveis** com curva versionada e recálculo pelo livro-razão.
- **Missões:** catálogo, atribuição semanal, validação por eventos, limite de simultâneas.
- **Conquistas:** regras versionadas e desbloqueio único.
- **Sequências** com recuperação e tolerância, no fuso da pessoa.
- **Desafios** com prazo, com as mesmas regras.
- **Conferência periódica** do livro-razão com a projeção.
- **Retorno visual** a partir de `xp.awarded`, `level.unlocked` e `achievement.unlocked`, com mensagens neutras.

Valores iniciais de XP e curva estão em [GAMIFICATION_ARCHITECTURE.md](../../architecture/GAMIFICATION_ARCHITECTURE.md), como proposta a calibrar.

## Dependências

- **Etapas 05.1 e 05.2 e Fase 04** concluídas, porque os critérios usam atividades e recuperação.
- **Fontes:** nenhuma externa.

## Arquivos e módulos esperados

```text
apps/api/app/domains/gamification/
apps/api/app/domains/gamification/rules/     Regras versionadas
apps/api/app/domains/missions/
apps/api/db/migrate/    xp_transactions, user_levels, streaks, achievements, user_achievements, missions, user_missions
apps/mobile/src/features/progression/
```

## Critérios de aceite

- `AC-06-01` (FR-GAME-001, FR-GAME-002): cada evento legítimo gera o lançamento correto, com regra e versão registradas. O mesmo evento processado em dois workers ao mesmo tempo gera um só lançamento. **Comprovado por:** teste de concorrência com banco real.
- `AC-06-02` (FR-GAME-003): apagar `user_levels` e recalcular chega ao mesmo nível. Mudar a curva não reduz o nível exibido. **Comprovado por:** testes.
- `AC-06-03` (FR-GAME-004): missões variam por esporte e nível: iniciante e avançado recebem missões diferentes. **Comprovado por:** testes.
- `AC-06-04` (FR-GAME-005): não existe rota para o cliente concluir missão ou conceder XP, e a conclusão ocorre a partir de eventos. **Comprovado por:** verificação das rotas e testes.
- `AC-06-05` (FR-GAME-006): uma conquista é desbloqueada só uma vez, mesmo com eventos simultâneos. **Comprovado por:** teste de concorrência.
- `AC-06-06` (FR-GAME-007): recuperação planejada mantém a sequência, e a tolerância impede zerar por um dia perdido, no fuso correto. **Comprovado por:** tabela de casos com datas fixas.
- `AC-06-07` (FR-GAME-008): atividades acima do teto não geram XP, nem punem; duração e distância não mudam a pontuação; atividade em dia de recuperação planejado não pontua, nem soma com recuperação. **Comprovado por:** tabela de casos, incluindo sete treinos na semana.
- `AC-06-08` (FR-GAME-009): excluir a atividade ou a refeição de origem gera estorno único, mesmo se a exclusão chegar antes da concessão, e a interface não o apresenta como perda. **Comprovado por:** testes de idempotência e de ordem invertida.
- `AC-06-09` (FR-GAME-010): uma verificação automática percorre todas as regras, missões, conquistas e desafios, e falha com um critério proibido plantado. Os eventos consumidos não trazem calorias, peso, duração ou distância. **Comprovado por:** teste com caso plantado e teste do payload.
- `AC-06-10` (FR-GAME-011): a pessoa vê cada lançamento e o motivo, isolado de outras contas. **Comprovado por:** testes.
- `AC-06-11` (FR-GAME-012): ganho de XP, nível e conquista têm retorno visual no mobile, acessível. **Comprovado por:** teste de componente e demonstração.
- `AC-06-12` (FR-GAME-013): desafios e recompensas virtuais seguem as mesmas regras de concessão e segurança. **Comprovado por:** testes e a verificação do `AC-06-09`.
- `AC-06-13` (NFR-SAFETY-002): mensagens seguem a lista de linguagem, sem medo de perder, e há verificação automática de textos estáticos. **Comprovado por:** teste sobre os textos e revisão.

## Testes

Concorrência, idempotência, estorno, fuso. Reprocessamento explícito depois de mudança de regra. Conferência entre livro-razão e projeção. Exclusão de conta apaga o histórico. Limites de domínio: Gamification não lê tabelas de Nutrition ou Activities.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Incentivo errado | Dano ao usuário | Critérios proibidos por construção, verificados |
| Pouco desafio para quem compete | Menos engajamento | Missões avançadas e recordes pessoais; observar o uso |
| Muitas regras | Manutenção difícil | Começar com poucas, declarativas |
| XP retroativo distorce | Progressão artificial | Atividades de `backfill` marcadas e decididas por regra |
| Curva errada | Progressão lenta ou rápida | Versionar e calibrar com dados |

## Entregáveis

Contextos, telas móveis, contrato, documentação das regras iniciais e relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais: teste de concorrência real e verificação de critérios proibidos no CI.

## Estratégia de revisão

`software-architect` (independência do motor), `backend-reviewer` (concorrência), `security-reviewer` (segurança de produto), `qa-reviewer`, `frontend-mobile-reviewer`. O responsável aprova valores e o tom das mensagens.
