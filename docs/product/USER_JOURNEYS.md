# Jornadas do usuário

Cenários concretos que orientam telas e testes. Os identificadores remetem a [FUNCTIONAL_REQUIREMENTS.md](FUNCTIONAL_REQUIREMENTS.md).

## 1. Iniciante registra a primeira refeição

**Quem:** pessoa adulta que quer começar a se cuidar e nunca usou um app do gênero.

1. Instala o app, cria a conta e confirma ter 18 anos ou mais (FR-ID-001).
2. Lê e aceita, de forma separada, o tratamento de dados e o envio de fotos para análise por IA, com aviso de transferência internacional quando existir (FR-ID-007, NFR-PRIVACY-001).
3. Informa que está começando a caminhar, como iniciante (FR-PROFILE-002).
4. Fotografa o almoço (FR-FOOD-001). A tela mostra "analisando", e a pessoa pode sair (FR-FOOD-003).
5. Vê o resultado: "arroz, feijão, frango grelhado, salada", com a porção de cada um em medida caseira, e "cerca de 550 a 750 kcal", com a confiança declarada (FR-FOOD-004, FR-FOOD-005, FR-FOOD-006).
6. Confirma com um toque (FR-FOOD-007). Vê a meta "registrar as refeições do dia" avançar (FR-GOALS-002).

**Exceções:**

| Situação | Comportamento |
|---|---|
| Permissão de câmera negada | Explica como liberar e oferece a galeria (FR-MOBILE-002) |
| Sem rede | Guarda a foto no aparelho e tenta depois (FR-MOBILE-002) |
| Foto sem comida | "Não encontramos comida nesta foto", com opção de nova foto ou registro manual (FR-FOOD-012, FR-FOOD-011) |
| Falha do provedor | Estado de falha, com nova tentativa e registro manual (FR-FOOD-003) |
| Consentimento de IA recusado | O app continua funcionando com registro manual |
| Limite de análises atingido | Mensagem clara, com registro manual disponível (NFR-COST-002) |

**O que o sistema não faz:** não pede meta de peso, não mostra "calorias restantes", não julga a refeição como boa ou ruim.

## 2. Correção de uma estimativa errada

**Quem:** pessoa que comeu uma feijoada, mas o sistema identificou feijão preto simples.

1. Abre o resultado e toca no item errado.
2. Busca "feijoada" no catálogo (FR-CATALOG-003). O item indica que é uma composição própria, com receita-base declarada (FR-CATALOG-002).
3. Ajusta a porção de "1 concha" para "2 conchas".
4. O sistema recalcula a faixa e registra a correção (FR-FOOD-008).
5. O histórico da análise guarda a estimativa original e a correção, o que alimenta a avaliação de qualidade (FR-FOOD-014, FR-FOOD-015).

**Exceções:**

| Situação | Comportamento |
|---|---|
| Alimento não existe no catálogo | Aceita um item livre sem dados nutricionais e deixa claro que a estimativa fica incompleta |
| Correção depois de confirmada | Permitida, gera novo registro no histórico |

**O que o sistema não faz:** não apresenta o valor corrigido como medição exata, pois a porção continua sendo informada pela pessoa.

## 3. Esportista experiente conecta o Strava

**Quem:** pessoa que corre em nível avançado, treina há anos e quer ver alimentação e treino no mesmo lugar.

1. Em Configurações, toca em "Connect with Strava" e autoriza (FR-STRAVA-001).
2. Se o escopo de atividades foi desmarcado, o app explica que a importação não funcionará e oferece refazer a conexão.
3. O histórico autorizado é importado em lotes, com progresso visível, sem bloquear o app (FR-STRAVA-007, FR-STRAVA-009).
4. Uma corrida nova chega por webhook e aparece com o link "View on Strava" (FR-STRAVA-003, FR-STRAVA-004, FR-STRAVA-013).
5. A meta "correr 3 vezes na semana" avança sozinha (FR-GOALS-007), e a missão calibrada para o nível avançado é validada pelo evento (FR-GAME-004, FR-GAME-005).
6. A pessoa apaga uma atividade no Strava. O app remove a atividade e estorna o XP, mantendo o lançamento e o motivo no histórico (FR-STRAVA-006, FR-GAME-009).

**Exceções:**

| Situação | Comportamento |
|---|---|
| Limite do Strava atingido | Importação pausa e retoma sozinha, sem erro para a pessoa (FR-STRAVA-009) |
| Webhook perdido | A reconciliação recupera (FR-STRAVA-010) |
| Capacidade de atletas do app atingida | A conexão é recusada com explicação; a pessoa continua com registro manual |

**O que o sistema não faz:** não mostra atividades a outras pessoas, não oferece segmentos nem feed, e não dá mais XP por correr muito acima do teto (FR-GAME-008).

## 4. Dia de recuperação sem perder a sequência

**Quem:** pessoa com 20 dias de sequência que decide descansar depois de um treino longo.

1. Marca o dia como recuperação no planejamento (FR-GOALS-008).
2. A sequência continua e ganha reconhecimento por respeitar a recuperação (FR-GAME-007).
3. Na semana seguinte, perde um dia sem motivo. A sequência usa a tolerância definida, em vez de zerar (FR-GAME-007).
4. O relatório semanal destaca a constância, com linguagem neutra (FR-PROG-002, NFR-SAFETY-002).

**O que o sistema não faz:** não envia "você vai perder sua sequência!" e não sugere compensar treino ou comida.

## 5. Revogar consentimento e excluir a conta

**Quem:** pessoa que não quer mais que as fotos sejam analisadas e, depois, decide sair.

1. Em Privacidade, revoga o consentimento de análise de fotos (FR-ID-008). Novas análises param, e o registro manual continua disponível.
2. Exporta os dados (FR-ID-005).
3. Se o Strava estiver conectado, a exclusão inclui a desconexão e a revogação do acesso (FR-STRAVA-011).
4. Confirma a exclusão da conta (FR-ID-004). Fotos, refeições, atividades, metas e XP são apagados ou anonimizados conforme a [política de retenção](../security/PRIVACY_AND_LGPD.md).
5. Recebe a confirmação. Só permanece o registro mínimo exigido, sem conteúdo de saúde (NFR-PRIVACY-003).

**Exceções:**

| Situação | Comportamento |
|---|---|
| Análise em andamento na hora da exclusão | É cancelada, e o resultado descartado |
| Falha ao revogar no Strava | Dados locais são apagados mesmo assim; a revogação fica em nova tentativa, com registro de auditoria |

**O que o sistema não faz:** não cobra, não exige contato com suporte e não dificulta a saída.
