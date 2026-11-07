# Fase 08 — Intelligence & Personalization

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** FR-PROG-001, FR-PROG-002, FR-PROG-003, FR-PROG-004, FR-WEB-005, FR-NOTIF-001, FR-NOTIF-002, FR-NOTIF-003, NFR-PRIVACY-006
- **ADRs:** [0008](../../architecture/decisions/0008-strava-data-boundaries.md), [0009](../../architecture/decisions/0009-gamification-safety-principles.md)

## Objetivo

Relatórios e recomendações baseados em dados reais da pessoa, contextualizados e explicáveis, sem diagnóstico nem incentivo a comportamento prejudicial.

## Escopo

**Inclui:** contextos Progress & Analytics e Notifications; evolução; relatórios semanais; análises de consistência; padrões; recomendações de hábito; personalização de missões; notificações.

**Não inclui:** diagnóstico, conselho médico, plano de dieta ou treino, comparação entre pessoas, envio de dados do Strava à IA.

## Funcionalidades

- **Projeções próprias,** acionadas por eventos e reconstruíveis pelas APIs públicas dos outros contextos.
- **Notifications:** preferências por tipo, horário de silêncio, push com textos genéricos, caixa de mensagens no app e idempotência.
- **Evolução:** consistência, sequências, e recordes e comparações de um catálogo fechado, só de constância, sem distância, tempo, volume nem tendências de calorias.
- **Relatório semanal** com o que foi registrado, gerado por regras. Linguagem neutra.
- **Insights por regras** primeiro, cada um com: dados usados, período, volume mínimo e texto aprovado.
- **Texto por IA:** opcional, só se houver ganho, com dados mínimos, nunca com dados do Strava, verificação depois de gerar e um modelo fixo como alternativa. Se for usada, passa por revisão e consentimento adequados.
- **Personalização de missões** pelos padrões de consistência, dentro dos critérios permitidos.
- **Recomendações** limitadas a hábitos permitidos em [HEALTH_DATA_SAFETY.md](../../security/HEALTH_DATA_SAFETY.md).

## Dependências

- **Fases 06 e 07** concluídas.
- **ADR 0008:** dados do Strava não vão à IA, salvo reavaliação aprovada.
- **Fontes:** consultar de novo o API Agreement do Strava, o serviço de push do Expo e a documentação do provedor de IA, se houver uso.

## Arquivos e módulos esperados

```text
apps/api/app/domains/progress_analytics/
apps/api/app/domains/progress_analytics/insights/   Regras versionadas
apps/api/app/domains/notifications/
apps/api/db/migrate/    progress_snapshots, weekly_reports, notifications, device_tokens
apps/mobile/src/features/reports/
apps/web/src/features/reports/
```

## Critérios de aceite

- `AC-08-01` (FR-PROG-001): evolução vem de dados reais, segue o catálogo fechado, e reconstruir as projeções pelas APIs públicas dá o mesmo resultado, inclusive para dados anteriores a esta fase. **Comprovado por:** teste de reconstrução.
- `AC-08-02` (FR-PROG-002): o relatório semanal usa somente dados da própria pessoa, e semanas com poucos dados geram uma mensagem adequada. **Comprovado por:** testes com duas contas e semana vazia.
- `AC-08-03` (FR-PROG-003): cada insight mostra os dados que usou, e não aparece abaixo do volume mínimo. **Comprovado por:** testes por regra.
- `AC-08-04` (FR-PROG-003): nenhum texto contém diagnóstico, inferência de saúde ou conselho sobre comer menos ou treinar mais. **Comprovado por:** conjunto de casos adversos, verificação automática e revisão pelo `security-reviewer`.
- `AC-08-05` (FR-PROG-004): missões personalizadas passam pela verificação de critérios proibidos. **Comprovado por:** teste.
- `AC-08-06` (NFR-PRIVACY-006): nenhuma chamada à IA contém dados do Strava, e sem texto de IA o produto funciona por completo. **Comprovado por:** teste sobre o conteúdo enviado ao adaptador e teste com a IA desligada.
- `AC-08-07` (FR-NOTIF-001, FR-NOTIF-002, FR-NOTIF-003): cada tipo é opcional; o horário de silêncio é respeitado no fuso; a caixa de mensagens mostra o mesmo que o push; reprocessar não entrega de novo; textos não trazem dados de saúde; encerrar a sessão revoga o aparelho. **Comprovado por:** testes e demonstração de push real em aparelho.
- `AC-08-08` (FR-WEB-005): o painel mostra evolução e relatórios, com os mesmos dados do mobile. **Comprovado por:** teste end-to-end.

## Testes

Regras de insight em tabela de casos. Padrões proibidos. Volume mínimo. Isolamento entre pessoas. Reconstrução. Exclusão de conta alcança relatórios. Textos gerados, se existirem, passam por um conjunto de avaliação com casos adversos.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Inferência indevida | Dano e perda de confiança | Regras antes de IA; volume mínimo; casos adversos |
| Correlação vira conselho | Conselho falso | Só fatos observados, sem causalidade |
| Custo de texto por IA | Gasto sem valor | Regras primeiro; IA só com ganho medido |
| Violação do termo do Strava | Perda de acesso | Proibição testada |
| Push difícil de testar | Falhas despercebidas | Teste em aparelho real, com registro |

## Entregáveis

Contexto, telas, relatório semanal, catálogo de regras de insight e relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais: conjunto de casos adversos executado e registrado.

## Estratégia de revisão

`security-reviewer` (principal: segurança de saúde), `software-architect` (projeções), `backend-reviewer`, `frontend-mobile-reviewer`, `qa-reviewer`. O responsável aprova os textos e o relatório.
