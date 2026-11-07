# PRD — Documento de requisitos do produto

Complementa a [visão do produto](PRODUCT_VISION.md). Os requisitos verificáveis, com identificadores, estão em [FUNCTIONAL_REQUIREMENTS.md](FUNCTIONAL_REQUIREMENTS.md). A ordem de entrega está no [roadmap](../roadmap/ROADMAP.md).

## Problema

Quem quer se cuidar enfrenta três atritos: registrar comida dá trabalho, os apps fingem uma precisão que não têm, e a motivação depende de culpa ou de números que premiam comportamentos ruins. Quem já pratica esporte tem os dados das atividades de um lado e a alimentação e os hábitos de outro, sem uma visão de evolução pessoal.

## Solução

Um único lugar para registrar refeições por foto, acompanhar metas de hábito e atividades, e ver a evolução por um sistema de jogo que premia constância.

## Escopo funcional

### Alimentação por foto (Food AI)

A pessoa fotografa a refeição, e o sistema identifica alimentos e preparações, estima porções, consulta bases nutricionais e calcula calorias e macronutrientes **em faixa**. A pessoa confirma com um toque ou corrige. Se a foto não mostra comida ou está ilegível, o sistema diz isso, em vez de inventar um número.

### Catálogo de alimentos

As bases de dados ficam atrás de adaptadores. O catálogo registra origem, versão e licença de cada item. Pratos brasileiros são compostos a partir de ingredientes, com receita-base declarada. A TBCA só entra com autorização por escrito ([ADR 0007](../architecture/decisions/0007-nutrition-data-sources.md)).

### Metas de hábito (Goals)

- **Etapa 1 (no beta):** metas diárias de hábito, como registrar as refeições do dia, incluir vegetais ou cumprir o treino planejado, com check-in manual.
- **Etapa 2:** metas semanais, planejamento, confirmação automática por atividades, dias de recuperação e adaptação à rotina.
- **Nunca:** meta ou teto de calorias, meta de peso, compensação de comida com exercício.

### Atividades e Strava

Registro manual de atividades e integração oficial com a API do Strava: conexão por OAuth, importação por webhook, sincronização inicial, atualização, exclusão, reconciliação, desconexão e apagamento dos dados. Dados do Strava são exibidos somente ao dono.

### Gamificação

XP, níveis, missões, conquistas, desafios, sequências de consistência e recompensas virtuais. Motor independente, baseado em eventos, com livro-razão auditável e proteção contra concessão duplicada. O nível de experiência por esporte calibra as missões.

### Evolução e inteligência

Visão de evolução, recordes pessoais, comparação com períodos anteriores, relatórios semanais, padrões, recomendações de hábito e notificações. Toda recomendação é explicável e nunca diagnóstica.

### Aplicações

- **Mobile (Expo):** câmera, registros, Strava, atividades, missões, notificações, evolução.
- **Web (React):** visão geral, calendário, históricos, evolução, metas, missões, conquistas, relatórios e configurações.

As telas acompanham cada fase em entregas verticais. A Fase 07 consolida a experiência completa.

## Primeiro entregável: beta fechado (M1)

Para ter gente usando bem antes do lançamento, o [marco M1](../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md) coloca nas mãos de até 10 pessoas:

- Cadastro, consentimento e exclusão de conta.
- Foto da refeição com estimativa em faixa, confirmação, correção e histórico.
- Metas diárias de hábito com check-in manual.

O beta **não** inclui Strava, gamificação ou o painel web completo.

## Fora de escopo

| Item | Motivo | Onde está registrado |
|---|---|---|
| Ranking entre usuários | Ideia a aprofundar; não pode usar dados do Strava | [ADR 0013](../architecture/decisions/0013-sport-ranking.md) |
| Meta ou teto de calorias | Segurança do produto; reavaliação com dados do beta exige nova decisão do responsável | [ADR 0011](../architecture/decisions/0011-no-calorie-goals.md) |
| Usuários menores de idade | MVP só para adultos | [ADR 0010](../architecture/decisions/0010-adults-only-mvp-and-consent.md) |
| Feed social, segmentos, comentários | Limite de não replicar o Strava | [ADR 0008](../architecture/decisions/0008-strava-data-boundaries.md) |
| Diagnóstico, prescrição de dieta ou treino | Não é ferramenta médica | [Segurança de dados de saúde](../security/HEALTH_DATA_SAFETY.md) |
| Cobrança | Modelo ainda não definido | [ADR 0012](../architecture/decisions/0012-monetization-options.md) |

## Métricas de produto

| Métrica | Definição | Coleta |
|---|---|---|
| Ativação | Conta nova com ao menos uma refeição confirmada em até 7 dias | Com consentimento, a partir do M1 |
| Retenção | Conta com atividade na semana 2 e na semana 4 após o cadastro | Com consentimento, a partir do M1 |
| Taxa de correção | Refeições corrigidas sobre refeições confirmadas | Sem identificar a pessoa em relatórios |
| Custo de IA | Custo por análise e por usuário ativo por mês | A partir da Fase 03 |
| Qualidade da análise | Métricas do [dataset de avaliação](../architecture/AI_ARCHITECTURE.md) | A partir da Fase 03 |

## Riscos de produto

| Risco | Efeito | Mitigação |
|---|---|---|
| Estimativa errada corrói a confiança | Abandono | Faixas honestas, correção rápida, avaliação contínua |
| Produto reforça relação ruim com comida | Dano ao usuário | [Regras de segurança](../security/HEALTH_DATA_SAFETY.md), sem meta calórica, linguagem revisada |
| Sem meta calórica o produto atrai menos | Menos adoção e receita | Hipótese medida no beta, [ADR 0011](../architecture/decisions/0011-no-calorie-goals.md) |
| Custo de IA supera a receita | Inviabilidade | Custo medido desde a Fase 03, limite por usuário |
| Base nutricional brasileira indisponível | Estimativas piores para pratos locais | Catálogo próprio composto de ingredientes e pedido de autorização à TBCA |
| Strava não libera mais de 10 atletas | Integração não escala | Beta sem Strava, webhooks e backfill limitado, pedido de revisão com antecedência |

## Pendências externas

Ações que dependem do responsável, fora do código:

1. Pedir autorização de uso comercial aos coordenadores da TBCA (`tbca.contato@usp.br`), de preferência antes da Fase 03.
2. Verificar a licença da TACO.
3. Consultar advogado sobre LGPD, política de privacidade e definição de quem é o controlador antes de ter usuários reais.
4. Ter assinatura do Strava para criar a aplicação na Fase 04, e pedir revisão quando se aproximar de 10 atletas.
5. Definir a marca.
