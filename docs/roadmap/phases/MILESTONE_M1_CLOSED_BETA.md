# Marco M1 — Beta fechado

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** NFR-OPS-003, NFR-OPS-004, NFR-OPS-005, NFR-PRIVACY-007, NFR-PRIVACY-008
- **ADRs:** [0015](../../architecture/decisions/0015-hosting-and-deployment.md), [0016](../../architecture/decisions/0016-closed-beta-milestone.md), [0011](../../architecture/decisions/0011-no-calorie-goals.md), [0012](../../architecture/decisions/0012-monetization-options.md)
- **Checklist:** [RELEASE_CHECKLIST.md](../../operations/RELEASE_CHECKLIST.md)

## Objetivo

Colocar a foto com estimativa e as metas diárias nas mãos de até 10 pessoas reais, em ambiente real, e aprender com uso de verdade antes de construir o restante. É a primeira resposta a "as pessoas usam isso?".

## Escopo

**Inclui:** hospedagem e deploy do beta; backups testados; distribuição interna do app; métricas de ativação e retenção com consentimento; política publicada; revisão de privacidade; preparação operacional; canal de retorno.

**Não inclui:** Strava, gamificação, painel web completo, cobrança, abertura ao público. Itens já feitos nas fases anteriores não são repetidos:

| Item | Onde foi feito |
|---|---|
| Consentimentos, exclusão de conta, retenção | Fase 02 |
| Monitoramento de erros | Fase 01 |
| Limite de custo de IA por usuário | Fase 03 |

## Funcionalidades

- **Ambiente:** decidir a hospedagem na ADR 0015. API, jobs, banco, Redis e armazenamento privado em produção de beta.
- **Deploy** reproduzível, com caminho de reversão testado, e migrations seguras.
- **Backups** automáticos, com restauração testada e data registrada.
- **Distribuição interna** do app, avaliando EAS com custo.
- **Métricas:** tabela mínima `usage_facts`, com ativação e retenção, somente com o consentimento `usage_metrics`.
- **Conformidade:** revisão por advogado, controlador definido, encarregado com contato público, política de privacidade e lista de operadores, registro de operações.
- **Operação:** procedimento de incidente, alertas essenciais.
- **Aprendizado:** canal para retorno, roteiro curto de conversa, registro de pedidos por meta de calorias, disposição a pagar e custo real por pessoa.
- **Encerramento:** forma de encerrar o beta e tratar os dados.

## Dependências

- **Fases 01, 02 e 03 e etapa 05.1** concluídas, com evidências.
- **Ações do responsável:** advogado, contas de hospedagem e lojas, escolha das pessoas convidadas.
- **Fontes a consultar:** preços e regiões de hospedagem; regras de teste das lojas; ANPD para prazos.

## Arquivos e módulos esperados

```text
Infraestrutura de deploy, conforme a ADR 0015
.github/workflows/            Deploy
docs/operations/              Procedimentos de deploy, restauração e incidente
docs/product/                 Política de privacidade publicada e operadores
apps/api/app/domains/progress_analytics/   Métricas mínimas de uso
```

## Critérios de aceite

- `AC-M1-01` (NFR-OPS-004): deploy a partir de commit com CI verde e reversão executada de verdade. **Comprovado por:** registro com data.
- `AC-M1-02` (NFR-OPS-003): backup automático, e uma restauração testada em ambiente separado, com controles equivalentes e descartado ao final, reaplicando a lista de exclusões. **Comprovado por:** registro com data e duração, e uma conta excluída que não volta.
- `AC-M1-03` (NFR-PRIVACY-008): registro de operações mantido, encarregado com contato público, e política publicada com lista de operadores. **Comprovado por:** link e documento.
- `AC-M1-04`: revisão por advogado concluída, com os ajustes aplicados. **Comprovado por:** registro das pendências de [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md) respondidas.
- `AC-M1-05` (NFR-OPS-005, NFR-PRIVACY-007): ativação e retenção são medidas segundo o PRD, somente para quem consentiu. **Comprovado por:** teste e consulta real.
- `AC-M1-06`: em produção de beta, uma conta nova cria, fotografa, confirma, corrige, faz check-in, exporta e exclui. **Comprovado por:** roteiro executado, com capturas de tela, sem dados pessoais reais.
- `AC-M1-07`: armazenamento privado confirmado, limite e alerta de gasto ativos, e monitoramento recebendo erros em ambiente real. **Comprovado por:** tentativas registradas.
- `AC-M1-08`: até 10 pessoas usam por um período definido no plano, e um relatório resume ativação, retenção, custo, retorno e pedidos por meta de calorias. **Comprovado por:** relatório do beta.
- `AC-M1-09`: o responsável decide, com base no relatório, os próximos passos sobre a ADR 0011, a ADR 0012 e a ordem das fases. **Comprovado por:** decisão registrada.
- `AC-M1-10`: ADR 0015 decidida. **Comprovado por:** leitura da ADR.
- `AC-M1-11`: antes de convidar pessoas, um profissional de saúde revisou exibição de calorias, tipos de meta, textos e fontes de apoio. **Comprovado por:** registro da revisão e das mudanças aplicadas.
- `AC-M1-12`: o retorno do beta está no inventário de dados, com destino definido ao encerrar. **Comprovado por:** [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md) atualizado e dados tratados no encerramento.

## Testes

Fumaça após o deploy; roteiro completo em produção de beta; restauração; métricas respeitando consentimento; exclusão alcançando também as métricas.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Revisão jurídica demora | Beta atrasa | Iniciar cedo; é pré-condição, não pular |
| Pessoas convidadas sendo muito próximas | Retorno enviesado | Incluir ao menos algumas fora do círculo próximo |
| Poucos usuários para métricas | Números pouco confiáveis | Tratar como qualitativo; conversar com as pessoas |
| Custo inesperado | Orçamento estoura | Limite por usuário e alerta |
| Dados sensíveis reais pela primeira vez | Dano em caso de falha | Checklist completo antes de convidar |

## Entregáveis

Ambiente de beta, ADR 0015 decidida, política publicada, procedimentos operacionais, relatório do beta com decisões e relatório do marco.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais a parte M1 do [checklist](../../operations/RELEASE_CHECKLIST.md).

## Estratégia de revisão

`security-reviewer` (principal, antes de convidar pessoas), `software-architect` (hospedagem), `qa-reviewer` (roteiro). Revisão externa por advogado. **O responsável aprova o convite às pessoas, e decide os próximos passos.**
