# Fase 09 — Production Readiness & Launch

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** NFR-OBS-003, NFR-PERF-004, NFR-OPS-006, NFR-SAFETY-005
- **ADRs:** [0015](../../architecture/decisions/0015-hosting-and-deployment.md), [0012](../../architecture/decisions/0012-monetization-options.md)
- **Checklist:** [RELEASE_CHECKLIST.md](../../operations/RELEASE_CHECKLIST.md)

## Objetivo

Reunir evidências de qualidade, segurança, disponibilidade e operação suficientes para um lançamento controlado. Reaproveita o que foi feito no M1, reavaliando para a nova escala.

## Escopo

**Inclui:** revisão de segurança; desempenho e escalabilidade; testes de integração e end-to-end; acessibilidade final; revisão de privacidade e LGPD; monitoramento completo; backups e recuperação; deploy de produção; documentação operacional; preparação de lojas; checklist de lançamento.

**Não inclui:** novas funcionalidades ou modo adolescente. Só documentar os requisitos para o caso de um dia existir, conforme NFR-SAFETY-005.

## Funcionalidades

- **Capacidade:** definir a meta do lançamento e validar com teste de carga, incluindo filas e custo de IA.
- **Reavaliação do M1:** hospedagem, backups, procedimento de incidente, métricas.
- **Observabilidade:** métricas e alertas completos, cada um com procedimento.
- **Segurança:** revisão completa de todas as superfícies do [modelo de ameaças](../../security/SECURITY.md).
- **Privacidade:** inventário, operadores, retenção e textos atualizados, com revisão jurídica.
- **Saúde:** revisão de textos e regras por profissional de saúde.
- **Migrations seguras** durante o lançamento.
- **Lojas:** requisitos para apps de saúde e pagamentos, consultados na fonte.
- **Strava:** capacidade aprovada ou oferta claramente limitada.

## Dependências

- **Fases 07, 08 e M1** concluídas, com o aprendizado do beta incorporado.
- **Ações do responsável:** marca definida, revisão jurídica, revisão por profissional de saúde, decisão de monetização ou lançamento gratuito.
- **Fontes a consultar de novo:** todas as do [registro](../../architecture/EXTERNAL_SOURCES.md).

## Arquivos e módulos esperados

```text
docs/operations/          Procedimentos por alerta, recuperação, deploy
docs/security/            Relatório de revisão
tests de carga            Local definido no plano
```

## Critérios de aceite

- `AC-09-01` (NFR-PERF-004): meta de capacidade definida e atendida em teste de carga, com custo estimado. **Comprovado por:** relatório do teste.
- `AC-09-02` (NFR-OBS-003): métricas e alertas existem para filas, outbox, webhooks e falhas de análise, e cada um foi disparado de propósito e tem procedimento. **Comprovado por:** registro dos disparos.
- `AC-09-03`: restauração completa de backup executada dentro do tempo definido, com ao menos uma simulação de desastre. **Comprovado por:** registro com data e duração.
- `AC-09-04` (NFR-OPS-006): uma migration real roda em ambiente semelhante à produção sem interromper o serviço. **Comprovado por:** registro.
- `AC-09-05`: revisão de segurança concluída, sem achado crítico ou importante em aberto, com teste de isolamento em todas as rotas. **Comprovado por:** relatório do `security-reviewer` e testes.
- `AC-09-06`: testes end-to-end cobrem os fluxos principais nas duas plataformas, e rodam antes de cada liberação. **Comprovado por:** execução registrada.
- `AC-09-07`: revisão jurídica concluída e aplicada, e revisão por profissional de saúde realizada. **Comprovado por:** registro das revisões e das mudanças feitas.
- `AC-09-08` (NFR-SAFETY-005): o documento de segurança de saúde descreve os requisitos para suporte a menores, e o produto segue bloqueando quem não confirma a maioridade. **Comprovado por:** leitura e teste.
- `AC-09-09`: cada item do [checklist de lançamento](../../operations/RELEASE_CHECKLIST.md) tem evidência. **Comprovado por:** checklist preenchido.
- `AC-09-10`: lançamento controlado aprovado pelo responsável, com plano de reversão. **Comprovado por:** aprovação registrada em `STATUS.md`.

## Testes

Carga, recuperação, end-to-end, segurança, acessibilidade e fumaça após o deploy.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Aprovação do Strava atrasa | Oferta limitada | Lançar com Strava limitado, decidido com antecedência |
| Rejeição nas lojas | Atraso | Consultar regras cedo |
| Pendências jurídicas | Bloqueio | Revisão já iniciada no M1 |
| Custo acima do orçamento | Inviabilidade | Limites e alertas; custo medido no beta |
| Operação por uma pessoa | Ponto único de falha | Procedimentos curtos e poucos alertas acionáveis |

## Entregáveis

Relatórios de carga, segurança e recuperação; documentação operacional; checklist preenchido; produto no ar em lançamento controlado; relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais o [checklist de lançamento](../../operations/RELEASE_CHECKLIST.md) completo.

## Estratégia de revisão

Todos os agentes, com foco em `security-reviewer` e `qa-reviewer`. Revisão externa jurídica e por profissional de saúde. O responsável aprova o lançamento.
