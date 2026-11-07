# Visão do produto

> "Fitness Companion" é nome de trabalho e `nexora` é o nome do diretório. Nenhum dos dois é marca definitiva. Por isso, código e pacotes usam nomes neutros de domínio.

## O que é

Um companheiro de evolução pessoal. A pessoa fotografa a refeição, recebe uma estimativa honesta do que comeu, acompanha hábitos e atividades, e vê a própria evolução em forma de jornada: níveis, missões, conquistas e sequências de consistência.

O propósito é transformar o cuidado com a saúde em algo que dê vontade de continuar, sem recorrer à culpa.

## Para quem

Do iniciante que está começando a se cuidar à pessoa esportiva e competitiva. As duas pontas convivem porque o produto se adapta ao **nível de experiência por esporte**. Alguém pode ser corredor experiente e iniciante em musculação.

| Perfil | O que quer | O que o produto oferece |
|---|---|---|
| Iniciante | Começar sem se sentir julgado | Missões pequenas, registro por foto com pouco esforço, comemoração de constância |
| Intermediário | Criar rotina | Metas de hábito, planejamento semanal, sequências que aceitam dias de recuperação |
| Esportivo e competitivo | Medir evolução | Histórico de atividades, recordes pessoais, comparação com períodos anteriores |

## Como a competição funciona

Cada pessoa vê a própria evolução. A competição é contra si mesma: recordes pessoais, sequências e comparação com o próprio passado.

Um ranking por esporte é uma ideia para aprofundar no futuro, fora das nove fases ([ADR 0013](../architecture/decisions/0013-sport-ranking.md)). Os termos do Strava não permitem usar dados vindos de lá em nada que outro usuário veja.

## Princípios de produto

1. **Honestidade sobre incerteza.** Foto não mede peso nem ingrediente escondido. Toda estimativa aparece em faixa, com a confiança declarada e a possibilidade de correção.
2. **Premiar o sustentável.** XP e conquistas reconhecem constância, cuidado e recuperação. Nunca restrição alimentar, déficit calórico, excesso de exercício ou perda de peso.
3. **Justiça entre níveis.** Os 20 minutos de um iniciante podem valer tanto quanto os 15 km de um experiente, porque se premia cumprir o que faz sentido para aquele perfil, não volume absoluto.
4. **Pouco esforço por padrão.** O registro padrão é tirar a foto e confirmar. Corrigir é sempre possível, nunca obrigatório.
5. **Os dados são da pessoa.** Ela entende o que é coletado, consente por finalidade, exporta e apaga sem pedir favor nem pagar por isso.

## O que o produto não é

- **Não é ferramenta médica.** Não diagnostica, não trata e não prescreve dieta ou treino.
- **Não é app de dieta restritiva.** Calorias aparecem como informação em faixa. Não há meta nem teto de calorias ([ADR 0011](../architecture/decisions/0011-no-calorie-goals.md)).
- **Não é réplica do Strava.** O termo de API proíbe replicar a funcionalidade dele. As atividades servem à evolução do usuário, sem feed social nem segmentos.
- **Não é para menores no MVP.** O produto é só para adultos ([ADR 0010](../architecture/decisions/0010-adults-only-mvp-and-consent.md)).

## Como saberemos que deu certo

Nas palavras do responsável: **ver as pessoas usando** e **encontrar uma forma eficaz de monetizar**.

| Sinal | Como medir | Quando |
|---|---|---|
| Ativação | Pessoas que confirmam ao menos uma refeição na primeira semana | Beta fechado (M1) |
| Retenção | Pessoas ativas na segunda e na quarta semana após o cadastro | Beta fechado (M1) |
| Sustentabilidade | Custo de IA por usuário ativo por mês | A partir da Fase 03 |
| Disposição a pagar | Validação das alternativas da [ADR 0012](../architecture/decisions/0012-monetization-options.md) | Após o M1 |

As metas numéricas são definidas no [marco M1](../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md). Métricas de uso só são coletadas com consentimento.

## Monetização

O modelo ainda não foi escolhido. As alternativas e a forma de validá-las estão na [ADR 0012](../architecture/decisions/0012-monetization-options.md). Limites que valem para qualquer modelo:

- Não vender dados de saúde.
- Não cobrar por exportação ou exclusão de dados.
- Não colocar proteções de segurança atrás de pagamento.
