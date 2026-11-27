# Privacidade e LGPD

> **Não é parecer jurídico.** É o entendimento de engenharia sobre a Lei 13.709/2018 ([fontes](../architecture/EXTERNAL_SOURCES.md)), para orientar o desenho. **Um advogado precisa revisar isto antes de haver usuários reais.**

## Enquadramento

- Dado referente à saúde é **dado pessoal sensível** (art. 5, II).
- O art. 11, §1, estende as regras ao tratamento que **revele** dados sensíveis e possa causar dano. Hábitos alimentares, fotos de refeições e atividades físicas podem revelar condições de saúde. **O produto trata todos eles como sensíveis**, mesmo quando a classificação seria discutível.
- **Pendência:** definir quem é o controlador (pessoa física ou jurídica). Isso afeta contratos, política e responsabilidades.

## Inventário de dados

As bases legais são **propostas**, sujeitas à revisão jurídica.

| Categoria | Dados | Finalidade | Base legal proposta | Compartilhamento | Retenção |
|---|---|---|---|---|---|
| Conta | E-mail, hash de senha, confirmação de maioridade | Autenticar, proteger a conta | Execução de contrato | Serviço de e-mail | Até a exclusão |
| Perfil | Nome de exibição, fuso, preferências | Personalizar | Execução de contrato | Nenhum | Até a exclusão |
| Perfil esportivo | Esportes e nível | Calibrar metas e missões | Consentimento (saúde) | Nenhum | Até a exclusão |
| Fotos de refeição (`food_photos`) | Imagem, normalizada e sem EXIF no envio à IA; a linha guarda chave do objeto, tipo, tamanho, estado e datas | Identificar alimentos | Consentimento específico e destacado (`food_photo_ai`) | Provedor de IA, armazenamento privado | 30 dias após a análise (ver "Retenção aplicada") |
| Refeições (`food_entries`, `food_items`) | Itens, porções, faixas de calorias e nutrientes, correções, origem (`ai` ou `user`), confiança | Histórico e evolução | Consentimento (saúde) | Nenhum | Até apagar a refeição ou a conta |
| Análises (`food_analysis_results`) | Provedor, modelo, versão do prompt, estado, código de erro e `raw_response` (resposta do modelo) | Qualidade, auditoria, reaproveitar o resultado | Consentimento (saúde) | Nenhum | 90 dias, ou até apagar a refeição, o que vier primeiro |
| Custo de IA (`ai_usage_records`) | Provedor, modelo, tokens, custo em dólar, data; o vínculo com a pessoa e com a análise | Controle de custo e de quota (NFR-COST-001) | Consentimento (saúde) | Nenhum | Vínculo por 90 dias, e depois só o custo, sem pessoa nem análise |
| Catálogo de alimentos (`food_catalog`, `food_compositions`) | Alimentos e composições (USDA e do projeto), sem dado de pessoa | Calcular as faixas | Não se aplica (sem dado pessoal) | Nenhum | Permanente, versionado no repositório |
| Atividades manuais | Tipo, duração, distância | Evolução | Consentimento (saúde) | Nenhum | Até a exclusão |
| Dados do Strava | Atividades autorizadas | Evolução, exibida só ao dono | Consentimento específico | Nenhum; nunca à IA | Até desconectar |
| Tokens do Strava | Tokens cifrados | Manter a integração | Consentimento específico | Nenhum | Até desconectar |
| Metas, XP, missões | Progresso | Experiência do produto | Consentimento (saúde) | Nenhum | Até a exclusão |
| Métricas de uso | Eventos de uso | Melhorar o produto | Consentimento próprio | Ferramenta de análise, se houver | A definir no M1 |
| Logs e erros | Identificadores técnicos, sem conteúdo de saúde | Segurança e operação | Legítimo interesse (a confirmar) | Ferramenta de monitoramento | Sentry: 30 dias, no plano gratuito. Logs: a definir no M1, junto com a hospedagem |
| Consentimentos e auditoria | Histórico de ações | Comprovar conformidade | Obrigação legal e exercício de direitos (a confirmar) | Nenhum | A confirmar |

## Consentimento

Requisitos do art. 11, I, e do art. 8:

- **Específico e destacado:** tela própria, separada dos termos gerais, para cada finalidade.
- **Sem autorização genérica**, que é nula (art. 8, §4).
- **Revogável** a qualquer momento, de forma gratuita e facilitada (art. 8, §5).
- **Versionado:** `consent_records` guarda a versão do texto, a data e a ação.
- **Só o necessário bloqueia:** recusar a análise de fotos não bloqueia o registro manual.
- **Textos:** versionados em `apps/api/config/consents/<purpose>.v<N>.md`. Os da versão 1 foram aprovados pelo responsável em 2026-11-13 e não têm revisão jurídica (M1). O texto de `food_photo_ai` está na v1, **sem operador nem região**: por isso, até existir a v2 (que nomeia o operador e a região, por decisão do responsável adiada para a Fase 07 junto com a escolha do provedor), todo envio real de foto é recusado com `consent_operator_mismatch`. A identificação do controlador e o contato do encarregado continuam pendentes nos próprios textos.

| Finalidade (`purpose`) | Quando é pedida | Sem ela |
|---|---|---|
| `health_data` | No cadastro | O produto não funciona, porque essa é a sua função. A tela explica isso |
| `food_photo_ai` | Antes da primeira foto | Registro manual |
| `strava_integration` | Ao conectar | Sem Strava |
| `usage_metrics` | Separada e opcional | Produto completo, sem métricas |
| `ai_evaluation_photos` | Só se um dia usarmos fotos de usuários para avaliação | A foto não é usada. Não existe no M1 |

### Efeito de revogar cada finalidade

| Finalidade | O que para | Dados já coletados |
|---|---|---|
| `food_photo_ai` | Food AI bloqueia novos envios e cancela análises em andamento (`FoodAi::CancelOnRevocation`): a foto sem análise concluída é apagada, o objeto sai do armazenamento e a refeição ligada recebe o desfecho `cancelled` | Refeições permanecem; a pessoa pode apagá-las. Foto já analisada e dentro dos 30 dias fica até o prazo (pendência jurídica 17) |
| `strava_integration` | Strava Integration desconecta | Apagados, como na desconexão |
| `usage_metrics` | Progress & Analytics para a coleta | `usage_facts` da pessoa apagados |
| `health_data` | Todo o tratamento, porque é a função do produto. Na Fase 03, todas as rotas de refeição, de busca de alimentos e de envio de foto respondem `consent_required`, e o job de análise, ao encontrar o consentimento revogado, cancela a foto como numa revogação de `food_photo_ai` | O contexto de perfil apaga esportes (com histórico), níveis, motivações e nome de exibição; ficam fuso horário e unidades, e a conta continua. As refeições, os itens, as análises e a exportação continuam gravadas até a pessoa excluir a conta ou apagar cada refeição (`DELETE /api/v1/food_entries/{id}` não exige `health_data`; pendência jurídica 18, resolvida em 2026-11-16). As funções de saúde ficam bloqueadas até nova concessão. Metas diárias de hábito (etapa 05.1): todas as rotas de `/api/v1/goals` e `/api/v1/goal_types` respondem `consent_required`, exceto `DELETE /api/v1/goals/{id}`; as metas e os check-ins continuam gravados até a pessoa apagar cada meta ou excluir a conta, como as refeições. Decisão do responsável de 2026-11-13; a revisão jurídica confirma |

**Estado na Fase 02 (a Fase 03 acrescenta as linhas de `food_photo_ai` e `health_data` acima):** só existia a Identity. Revogar `health_data` funciona como as outras finalidades: registro, evento `consent.revoked` e apagamento das informações de saúde do perfil (esportes, níveis, motivações e nome de exibição), sem exigir a exclusão da conta. As demais finalidades já podem ser concedidas e revogadas, com registro e evento `consent.revoked`, mas ainda não têm tratamento a interromper. Um novo consentimento de `health_data` só é aceito depois que a retirada anterior foi aplicada (em geral em menos de um minuto); antes disso a API responde `409 revocation_pending`, para que nada escrito antes da retirada sobreviva a ela.

Toda fase que cria um novo tratamento atualiza esta tabela e testa a interrupção.

## Direitos do titular (art. 18)

Gratuitos (§5).

| Direito | Fluxo | Estado |
|---|---|---|
| Confirmação da existência de tratamento (I) | `GET /api/v1/consents` mostra, por finalidade, o que está concedido; `POST /api/v1/account/export` lista o que há por contexto | Implementado na Fase 02 |
| Acesso (II) | Exportação da conta (`POST /api/v1/account/export`, com a senha pedida de novo, resposta `no-store` e fora dos logs); perfil e sessões nas telas | Implementado na Fase 02. Fase 03: a exportação inclui refeições e itens (Nutrition) e, do Food AI, a lista de fotos (id, tipo, tamanho, estado e datas), as análises (provedor, modelo, versões, estado, código de erro e datas) e o custo de IA da pessoa. **Não inclui** os bytes da foto nem `raw_response`; o alcance do direito de acesso é a pendência jurídica 20. Atividades entram quando a fase de Strava registrar seu contexto |
| Correção (III) | `PATCH /api/v1/profile` e `POST`/`DELETE /api/v1/sport_profiles` | Implementado na Fase 02 para perfil. Refeições: item corrigido, removido ou acrescentado pela API (`PATCH`/`POST`/`DELETE /api/v1/food_entries/{id}/items`), e o app oferece remover e acrescentar item (Fase 03) |
| Anonimização, bloqueio ou eliminação do desnecessário ou excessivo (IV) | Rotinas diárias de retenção: `Identity::RetentionJob` (sessões vencidas ou revogadas há mais de 30 dias; `audit_events` e `consent_records` além do prazo provisório de 5 anos) e `Shared::Outbox::CleanupJob` (só eventos publicados há mais de 30 dias; eventos mortos ficam até serem resolvidos). Pedidos fora do que as rotinas cobrem: contato com o encarregado | Rotinas implementadas na Fase 02. Contato com o encarregado: documentado, fora desta fase (indicação antes do M1) |
| Portabilidade (V) | A exportação da conta devolve JSON estruturado | Implementado na Fase 02. A pendência jurídica sobre o alcance do direito segue aberta |
| Eliminação dos dados tratados com consentimento (VI) | `DELETE /api/v1/account`: sessões revogadas na hora e apagamento por contexto em até 24 horas, com o resíduo mínimo descrito abaixo. Revogar uma finalidade interrompe o tratamento (tabela de efeitos) | Conta: implementado na Fase 02. Refeição: `DELETE /api/v1/food_entries/{id}` apaga a refeição, os itens, a foto, o objeto e as análises, e o custo fica sem vínculo (Fase 03). Atividade: documentado, fora desta fase (Strava) |
| Informação sobre compartilhamento (VII) | Política de privacidade, com a lista de operadores | Documentado, fora desta fase (M1) |
| Informação sobre a possibilidade de não consentir e suas consequências (VIII) | Texto de cada tela de consentimento (`GET /api/v1/consents/{purpose}/text`) e coluna "Sem ela" da tabela de finalidades | Implementado na Fase 02. Textos sem revisão jurídica |
| Revogação do consentimento (IX) | `DELETE /api/v1/consents/{purpose}`, tão fácil quanto conceder, com registro e evento `consent.revoked`. Efeito na Fase 02: o consentimento passa a revogado e nenhum tratamento depende dele ainda; `health_data` também é revogado assim e apaga as informações de saúde do perfil, sem exigir a exclusão da conta | Implementado na Fase 02. Efeito sobre o tratamento de refeições e fotos: tabela de efeitos acima, testado na Fase 03 (`apps/api/spec/domains/food_ai/request_and_revocation_spec.rb`). Strava: fora desta fase |

Esta tabela descreve o fluxo técnico e **não é parecer jurídico**: a adequação de cada fluxo e os prazos continuam nas pendências da revisão jurídica. Os direitos são gratuitos (§5), e o canal e o prazo de resposta ao titular dependem da indicação do encarregado.

### Retenção aplicada

Prazos provisórios, a confirmar na revisão jurídica ([DATABASE_DESIGN.md](../architecture/DATABASE_DESIGN.md)). As rotinas, agendadas em `config/schedule.yml` (horários do cron; o fuso do agendador não foi verificado), apagam em lotes e podem rodar de novo sem efeito. O registro delas contém só contagens.

| Dado | Prazo aplicado | Rotina |
|---|---|---|
| `sessions` | 30 dias após expirar ou ser revogada | `Identity::RetentionJob` |
| `audit_events` | 5 anos (provisório) | `Identity::RetentionJob` |
| `consent_records` | 5 anos (provisório). O último registro de cada finalidade de uma conta ativa permanece, porque é a prova do que está concedido hoje; o de conta excluída segue o prazo | `Identity::RetentionJob` |
| `outbox_events` e `consumed_events` | 30 dias após a publicação; os eventos pendentes e os mortos permanecem até serem resolvidos ([runbook](../operations/RUNBOOK_OUTBOX.md)) | `Shared::Outbox::CleanupJob` |
| Objeto da foto (armazenamento) e `food_photos` | **30 dias após a análise**: o objeto é apagado e a linha vira `deleted`; a refeição fica. **1 hora** para envio abandonado (autorizado e não concluído). **24 horas** para foto armazenada e nunca analisada, sem análise em andamento. A linha da foto apagada fica **7 dias de carência** (para um job em andamento encontrá-la e descartar o resultado) e só sai se o objeto foi de fato apagado; o varredor tenta de novo todo dia | `FoodAi::PhotoRetentionJob` (04:15) |
| Refeição que nunca recebeu a foto | `pending` há mais de 1 hora: a refeição, a foto e o objeto são apagados | `Nutrition::AbandonedEntriesJob` (a cada hora, minuto 5) |
| `food_analysis_results` (inclui `raw_response`) | 90 dias após a criação, ou ao apagar a refeição, o que vier primeiro | `FoodAi::AnalysisRetentionJob` (04:30) |
| `ai_usage_records` | Aos 90 dias perdem `user_id` e `analysis_id` e ficam só como custo (provedor, modelo, tokens, valor). Ao apagar a refeição ou a conta, o vínculo sai na hora | `FoodAi::AnalysisRetentionJob` (04:30) |
| Refeição travada em processamento | Há mais de 15 minutos: retomada, ou marcada como falha (não é retenção; cabe aqui por mexer na foto) | `Nutrition::StuckEntriesJob` (a cada 10 minutos) |
| `account_deletions` concluídas | Já guardam só o UUID e as datas, como registro para reaplicar exclusões após restaurar backup; nenhuma rotina as apaga | n/a |
| `goal_removed_food_entries` (marcador de refeição apagada: só `user_id` e o id da refeição) | 30 dias após a criação, ou na exclusão da conta; fora da exportação, por ser só id de outro contexto | `Goals::RemovedFoodEntriesRetentionJob` (diário, 04:00) |
| `goals` e `goal_check_ins` | Retidos até a pessoa apagar a meta ou a conta. Sem rotina de expurgo; o prazo fica a confirmar na pendência jurídica de retenção | n/a |

## Exclusão de conta

Fluxo por eventos, com estado acompanhado:

1. A pessoa confirma, com reautenticação. Na mesma transação, as sessões de todos os aparelhos são revogadas, `account_deletions` é criado, e `user.deletion_requested` é publicado. Desde o pedido, a conta não entra, não redefine a senha nem consente.
2. Um job de Identity percorre o registro compartilhado de apagadores (`shared/data_registry`), no qual cada contexto com dados de usuário inscreve o seu `eraser` ao iniciar. Os contextos não chamam Identity, e nem Identity nem `shared/` citam constantes de outros contextos. Cada apagador concluído é marcado em `account_deletions.pending_contexts`, e uma falha repete só o que falta. Eventos da pessoa que cheguem depois do pedido são descartados, exceto `user.deletion_requested`. O prazo é de 24 horas: uma rotina horária enfileira de novo o que não terminou e, passado o prazo, dispara alerta só com o id da exclusão, nunca o e-mail.
3. Fotos são removidas do armazenamento (`FoodAi::UserData.erase`: primeiro os objetos, depois as linhas; o custo de IA fica sem vínculo com a pessoa). A integração com o Strava é revogada.
4. Os registros necessários para comprovar conformidade permanecem, sem conteúdo de saúde. O que sobra da conta: a linha de `users` com o mesmo UUID, o e-mail trocado por um valor aleatório, sem senha e com `deleted_at`; `consent_records` e `audit_events` seguem ligados a esse UUID. Para reaplicar exclusões após restaurar backup, guarda-se só o UUID e a data. O mesmo e-mail pode criar outra conta. A revisão jurídica ainda precisa confirmar que esse resíduo é o mínimo necessário.
5. Backups: os dados expiram com a rotação, cujo prazo fica na política. Qualquer restauração reaplica a lista de exclusões antes de voltar ao ar. Operadores: registros do provedor de IA, monitoramento e e-mail seguem a política de cada um, informada na lista de operadores.

O prazo de conclusão é de 24 horas, definido na Fase 02. Um teste automático semeia cada tabela, inclusive campos JSON, com um marcador, e confirma que nada de usuário permanece, salvo os registros mínimos do passo 4.

## Transferência internacional (art. 33)

Enviar fotos a um provedor de IA em outro país é transferência internacional. As hipóteses incluem cláusulas contratuais (II) e consentimento específico e destacado com informação prévia sobre o caráter internacional (VIII).

**Proposta:** informar a transferência na tela de `food_photo_ai`, com operador e região ligados à versão do consentimento, e revisar os termos do provedor na Fase 07, quando a escolha for feita. Na Fase 03 não há provedor configurado, e nenhuma foto sai do armazenamento. O mesmo vale para hospedagem, armazenamento, e-mail e monitoramento, caso estejam fora do Brasil.

## Operadores

Provedor de IA, hospedagem, armazenamento, e-mail, monitoramento e serviço de push são operadores. Antes do M1: lista pública e revisão dos termos de cada um. Nenhum deles pode usar os dados para fins próprios, como treinamento.

**Monitoramento: Sentry,** decidido em 2026-11-06, no plano gratuito. Recebe tipo e pilha do erro, um identificador de correlação e o papel do processo, sem mensagem da exceção, usuário, parâmetros, cabeçalhos ou cookies. Pendências para a revisão jurídica: se a seção 17 dos termos, sobre produtos sem custo, alcança o plano Developer; a região de armazenamento escolhida, e a transferência internacional do que fica nos EUA; e se identificadores técnicos enviados ao operador se enquadram como dados pessoais.

## Registro e governança

- **Registro de operações** (art. 37): este inventário é a base, e será mantido atualizado a cada fase.
- **Encarregado** (art. 41): indicar antes do M1, com contato público.
- **Relatório de impacto:** avaliar a necessidade com o advogado, dado o volume de dados sensíveis.
- **Incidentes** (art. 48): ver [SECURITY.md](SECURITY.md).

## Regras de minimização

- Não coletar peso, medidas, condições médicas ou medicamentos.
- Remover EXIF das fotos antes de enviar à IA.
- Não enviar nome, e-mail ou histórico no prompt.
- Logs sem conteúdo de saúde, fotos ou tokens.
- Métricas com o mínimo necessário.

## Pendências para a revisão jurídica

1. Base legal de cada linha do inventário.
2. Quem é o controlador.
3. Suficiência da confirmação declaratória de maioridade.
4. Prazos de retenção, incluindo consentimentos e auditoria.
5. Textos das telas de consentimento e da política de privacidade.
6. Termos dos operadores e transferência internacional.
7. Prazo vigente de comunicação de incidentes, conforme a ANPD.
8. Se monetização futura muda alguma base.
9. Destino dos dados após revogar `health_data`, e granularidade dessa finalidade.
10. Critério de anonimização de registros mantidos.
11. Pessoas e menores que apareçam em fotos, e aviso na tela de consentimento.
12. Retorno do beta (conversas e pedidos): categoria de dado e destinação ao encerrar.
13. Normas além da LGPD citadas na revisão interna, sem verificação na fonte: resolução da ANPD sobre prazo de incidente, ECA Digital e regras da Anvisa sobre software como dispositivo médico.
14. Marco Civil da Internet (Lei 12.965/2014, art. 15), sem verificação na fonte: se o dever de guardar registros de acesso à aplicação conflita com o `ip_hmac` não reversível de `audit_events`, que não permite recuperar o IP. Não decidido.
15. Retenção de evento morto da outbox sem resolução: hoje ele fica até alguém resolver (não há prazo), e o evento carrega só identificadores. Se isso exige um prazo máximo, a revisão jurídica define. Não decidido.
16. Divergência da política de retenção da Anthropic: a página da documentação diz que o conteúdo *"is not retained by default"* (com exceções), e a central de privacidade diz que apaga entradas e saídas *"within 30 days"*, com conteúdo sinalizado por até 2 anos ([fontes](../architecture/EXTERNAL_SOURCES.md), consulta de 2026-11-13). O texto do consentimento v2 precisa dizer o que vale.
17. Foto já analisada depois da revogação de `food_photo_ai`: ela fica no armazenamento até 30 dias após a análise. Decidir se a revogação deve apagá-la na hora.
18. Dados depois da revogação de `health_data`: refeições, análises e exportação permanecem. Destino decidido junto com a pendência 9. Parte resolvida em 2026-11-16: apagar a refeição não exige `health_data` (`DELETE /api/v1/food_entries/{id}`; as demais rotas de refeição continuam exigindo).
19. Região do Gemini: os termos adicionais da API (vigentes desde 2026-03-23) falam em guardar dados "em qualquer país com instalações do Google" e em registro por "período limitado" sem prazo declarado. A região precisa ser conhecida e ligada à versão do consentimento (operador e região). O nível gratuito é proibido.
20. Alcance do direito de acesso e da portabilidade: a exportação não traz os bytes da foto nem `raw_response`, e a revisão confirma se isso basta.
21. Hipótese do art. 33 para a transferência internacional das fotos (cláusulas contratuais ou consentimento específico), por provedor.
22. Pessoas e menores nas fotos de refeição, e o aviso na tela de consentimento (reforça a pendência 11).
23. A licença LGPL-2.1-or-later da libvips em SaaS, com ligação dinâmica e sem modificação ([ADR 0019](../architecture/decisions/0019-photo-storage-and-image-processing.md)).
24. Backup do iOS das fotos pendentes no aparelho: a cópia local de uma foto não enviada fica em `documentDirectory`, que o iOS inclui no backup do aparelho. No Android o backup está desligado (`allowBackup: false`). A alternativa, `cacheDirectory`, pode ser limpa pelo sistema e perder a foto (FR-MOBILE-002). Decisão técnica registrada; a exclusão do backup do iOS e o parecer ficam pendentes.
25. Groq como operador candidato (acrescentada em 2026-11-25, plano gratuito): dados retidos em buckets do GCP nos EUA e local da inferência não informado, o que entra na hipótese do art. 33 (pendência 21). A proibição de treino vem do Contrato de Serviços, seção 4.2; o DPA e o Trust Center não foram lidos. O plano gratuito pode registrar entradas e saídas por até 30 dias, salvo recusa ou ZDR em Data Controls. Antes de qualquer foto de pessoa, o ZDR precisa estar ligado e registrado ([fontes](../architecture/EXTERNAL_SOURCES.md), linhas da Groq).
