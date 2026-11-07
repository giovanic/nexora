# Segurança de saúde no produto

Como evitar que o produto faça mal. Este documento vale para telas, notificações, textos de IA, missões, conquistas e relatórios. Mudar qualquer limite aqui exige ADR aprovada pelo responsável.

> Estas regras são critérios de engenharia e produto, escritos sem revisão de um profissional de saúde. Recomenda-se revisão por profissional qualificado antes do lançamento.

## Limites do produto

- **Não é ferramenta médica.** Não diagnostica, não trata, não prescreve dieta nem treino.
- **Não infere condições de saúde.** Nem transtornos alimentares, nem deficiências, nem riscos cardíacos.
- **Não substitui profissional.** Quando adequado, sugere procurar um profissional, sem alarme.
- **Só para adultos no MVP** ([ADR 0010](../architecture/decisions/0010-adults-only-mvp-and-consent.md)).

## Como mostrar calorias

| Faça | Não faça |
|---|---|
| "Cerca de 550 a 750 kcal" | "632 kcal" |
| Declarar que é estimativa e sua confiança | Apresentar como medição |
| Mostrar como informação da refeição | "Calorias restantes", "acima do limite", "você passou" |
| Cor neutra | Vermelho, verde ou alertas conforme a quantidade |
| Oferecer correção sem julgamento | Classificar comida como boa, ruim, limpa ou lixo |

Não existe meta nem teto de calorias ([ADR 0011](../architecture/decisions/0011-no-calorie-goals.md)). Calorias queimadas não são apresentadas como algo que "compensa" comida.

Também é proibido mostrar total ou tendência de calorias entre períodos, porque isso funciona como acompanhamento de déficit mesmo sem meta. A refeição mostra sua faixa, e relatórios tratam de constância.

## Metas permitidas e proibidas

| Permitidas | Proibidas |
|---|---|
| Registrar as refeições do dia | Meta ou teto de calorias |
| Incluir vegetais ou frutas | Déficit calórico |
| Cumprir o treino planejado | Meta de peso, medidas ou percentual de gordura |
| Beber água | Jejum, pular refeição, "dia limpo" |
| Dormir mais cedo | Compensar comida com exercício |
| Respeitar o dia de recuperação | Treinar todos os dias sem descanso |

A lista fechada de tipos fica no código e no banco (FR-GOALS-005).

## Gamificação

Critérios proibidos e limites estão em [GAMIFICATION_ARCHITECTURE.md](../architecture/GAMIFICATION_ARCHITECTURE.md) e na [ADR 0009](../architecture/decisions/0009-gamification-safety-principles.md). Resumo:

- XP não usa calorias, déficit, peso ou volume absoluto.
- Sessão de atividade tem teto diário e semanal.
- Recuperação planejada pontua.
- Sequências têm tolerância, e não há medo de perder.

## Linguagem

Lista usada em revisão e em verificação automática de textos estáticos (NFR-SAFETY-002).

| Evitar | Por quê | Preferir |
|---|---|---|
| "Você vai perder sua sequência!" | Medo e urgência | "Sua sequência continua quando quiser retomar." |
| "Queime o que comeu" | Compensação | Nunca sugerir |
| "Refeição ruim", "besteira", "pecado", "culpa", "trapaça" | Julgamento moral | "Registrado." |
| "Você passou do limite" | Não há limite | Nunca dizer |
| "Corpo dos sonhos", "secar", "barriga", "emagrecer" | Foco no corpo | "Cuidar de você", "constância" |
| "Sem desculpas", "sem dor, sem ganho" | Incentiva excesso | "Descansar também faz parte." |
| "Sua alimentação indica deficiência de ferro" | Diagnóstico | "Fale com um profissional de nutrição, se tiver dúvidas." |
| "Você deveria comer menos" | Prescrição | Nunca dizer |

A lista serve como ponto de partida. Palavras em contexto legítimo podem ser liberadas com justificativa.

## Textos gerados por IA

- **Food AI:** o modelo só observa alimentos; o texto não traz conselhos nem julgamento.
- **Fase 08:** textos passam por regras, e por uma lista bloqueada. Em dúvida, usa-se um modelo fixo.
- **Sem conselho médico.** O prompt proíbe, e a verificação pós-geração reforça.
- **Dados mínimos:** nada além do necessário, e nunca dados do Strava.

## Insights e recomendações

Recordes e comparações seguem um catálogo fechado, só de constância: sequências, semanas com recuperação planejada, dias com registro. Nada de recorde de distância, tempo ou volume.

Permitido: "Você registrou refeições em 5 de 7 dias." "Você fez seu dia de recuperação planejado."

Proibido: "Você comeu pouco esta semana." "Você está comendo demais." "Você deveria treinar mais." Conclusões a partir de pouco dado ou que digam algo sobre a saúde da pessoa.

Cada insight precisa mostrar os dados em que se baseia e ter volume mínimo de dados (FR-PROG-003).

## Sinais de risco

O produto **não diagnostica** e não tenta detectar transtornos. Ainda assim, algumas proteções passivas valem para todos:

- O produto não elogia nem premia quantidades baixas de comida, e Gamification nem recebe esse dado.
- Atividade acima do teto não gera incentivo. A sugestão de um dia de recuperação parte só de contagem de sessões e da revisão profissional.
- A central de ajuda traz informação clara e sem alarme sobre onde procurar apoio profissional.

Fontes de apoio, exibição de calorias, metas e textos são revisados por profissional de saúde **antes do M1**, porque o beta já expõe pessoas reais, e de novo na Fase 09.

## Modo adolescente (fora do MVP)

Se houver decisão de suportar menores, é necessário, no mínimo:

- Uma nova ADR, além de revisão jurídica específica (LGPD, art. 14) e profissional.
- Consentimento adequado ao caso legal, incluindo o de responsáveis onde for exigido.
- **Sem** metas de restrição alimentar, déficit calórico, emagrecimento.
- **Sem** gamificação baseada no corpo ou no gasto calórico.
- **Sem** exibição de calorias por padrão.
- Linguagem revisada para essa idade.

## Notificações

Textos genéricos, sem dados de saúde, conteúdo de refeição ou dados do Strava, porque aparecem na tela de bloqueio e passam pelo serviço de push: por exemplo, "Sua semana está pronta para ver." Nada de urgência ou medo de perder.

## Como isso é verificado

| Verificação | Onde |
|---|---|
| Teste de critérios proibidos de XP | Fase 06 |
| Rejeição de tipos de meta proibidos | Fase 05 |
| Verificação de textos estáticos contra a lista de linguagem | Fase 03 em diante |
| Estimativas sempre em faixa, por teste de contrato | Fase 03 |
| Revisão pelo `security-reviewer` e pelo `qa-reviewer` | A cada fase com texto ou regra novos |
| Revisão por profissional de saúde | M1 e Fase 09 |
