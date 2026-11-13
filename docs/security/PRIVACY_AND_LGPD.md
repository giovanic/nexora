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
| Fotos de refeição | Imagem, sem EXIF no envio à IA | Identificar alimentos | Consentimento específico e destacado | Provedor de IA, armazenamento | Até apagar a refeição; prazo máximo decidido na Fase 03 |
| Refeições | Itens, porções, faixas, correções | Histórico e evolução | Consentimento (saúde) | Nenhum | Até a exclusão |
| Registros de análise | Prompt, modelo, resposta, custo | Qualidade, custo, auditoria | Consentimento (saúde) | Nenhum | 90 dias com vínculo; depois anonimizado |
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
- **Textos:** versionados em `apps/api/config/consents/<purpose>.v<N>.md`. Os da versão 1 são rascunhos, aguardando a aprovação do responsável, e não têm revisão jurídica.

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
| `food_photo_ai` | Food AI bloqueia novos envios e cancela análises em andamento | Refeições permanecem; a pessoa pode apagá-las |
| `strava_integration` | Strava Integration desconecta | Apagados, como na desconexão |
| `usage_metrics` | Progress & Analytics para a coleta | `usage_facts` da pessoa apagados |
| `health_data` | Todo o tratamento, porque é a função do produto | O contexto de perfil apaga esportes (com histórico), níveis, motivações e nome de exibição; ficam fuso horário e unidades, e a conta continua. As funções de saúde ficam bloqueadas até nova concessão. Decisão do responsável de 2026-11-13; a revisão jurídica confirma |

**Estado na Fase 02:** só existe a Identity. Revogar `health_data` funciona como as outras finalidades: registro, evento `consent.revoked` e apagamento das informações de saúde do perfil (esportes, níveis, motivações e nome de exibição), sem exigir a exclusão da conta. As demais finalidades já podem ser concedidas e revogadas, com registro e evento `consent.revoked`, mas ainda não têm tratamento a interromper. Um novo consentimento de `health_data` só é aceito depois que a retirada anterior foi aplicada (em geral em menos de um minuto); antes disso a API responde `409 revocation_pending`, para que nada escrito antes da retirada sobreviva a ela.

Toda fase que cria um novo tratamento atualiza esta tabela e testa a interrupção.

## Direitos do titular (art. 18)

Gratuitos (§5).

| Direito | Fluxo | Estado |
|---|---|---|
| Confirmação da existência de tratamento (I) | `GET /api/v1/consents` mostra, por finalidade, o que está concedido; `POST /api/v1/account/export` lista o que há por contexto | Implementado na Fase 02 |
| Acesso (II) | Exportação da conta (`POST /api/v1/account/export`, com a senha pedida de novo, resposta `no-store` e fora dos logs); perfil e sessões nas telas | Implementado na Fase 02. Dados de refeições e atividades entram na exportação quando a Fase 03 e a de Strava registrarem seus contextos |
| Correção (III) | `PATCH /api/v1/profile` e `POST`/`DELETE /api/v1/sport_profiles` | Implementado na Fase 02 para perfil. Refeições: documentado, fora desta fase (Fase 03) |
| Anonimização, bloqueio ou eliminação do desnecessário ou excessivo (IV) | Rotinas diárias de retenção: `Identity::RetentionJob` (sessões vencidas ou revogadas há mais de 30 dias; `audit_events` e `consent_records` além do prazo provisório de 5 anos) e `Shared::Outbox::CleanupJob` (só eventos publicados há mais de 30 dias; eventos mortos ficam até serem resolvidos). Pedidos fora do que as rotinas cobrem: contato com o encarregado | Rotinas implementadas na Fase 02. Contato com o encarregado: documentado, fora desta fase (indicação antes do M1) |
| Portabilidade (V) | A exportação da conta devolve JSON estruturado | Implementado na Fase 02. A pendência jurídica sobre o alcance do direito segue aberta |
| Eliminação dos dados tratados com consentimento (VI) | `DELETE /api/v1/account`: sessões revogadas na hora e apagamento por contexto em até 24 horas, com o resíduo mínimo descrito abaixo. Revogar uma finalidade interrompe o tratamento (tabela de efeitos) | Conta: implementado na Fase 02. Exclusão de refeição e de atividade: documentado, fora desta fase (Fase 03 e Strava) |
| Informação sobre compartilhamento (VII) | Política de privacidade, com a lista de operadores | Documentado, fora desta fase (M1) |
| Informação sobre a possibilidade de não consentir e suas consequências (VIII) | Texto de cada tela de consentimento (`GET /api/v1/consents/{purpose}/text`) e coluna "Sem ela" da tabela de finalidades | Implementado na Fase 02. Textos sem revisão jurídica |
| Revogação do consentimento (IX) | `DELETE /api/v1/consents/{purpose}`, tão fácil quanto conceder, com registro e evento `consent.revoked`. Efeito na Fase 02: o consentimento passa a revogado e nenhum tratamento depende dele ainda; `health_data` também é revogado assim e apaga as informações de saúde do perfil, sem exigir a exclusão da conta | Implementado na Fase 02. Efeito sobre cada tratamento: documentado, fora desta fase (cada fase testa a interrupção) |

Esta tabela descreve o fluxo técnico e **não é parecer jurídico**: a adequação de cada fluxo e os prazos continuam nas pendências da revisão jurídica. Os direitos são gratuitos (§5), e o canal e o prazo de resposta ao titular dependem da indicação do encarregado.

### Retenção aplicada

Prazos provisórios, a confirmar na revisão jurídica ([DATABASE_DESIGN.md](../architecture/DATABASE_DESIGN.md)). Duas rotinas diárias, agendadas em `config/schedule.yml`, apagam em lotes e podem rodar de novo sem efeito. O registro delas contém só contagens.

| Dado | Prazo aplicado | Rotina |
|---|---|---|
| `sessions` | 30 dias após expirar ou ser revogada | `Identity::RetentionJob` |
| `audit_events` | 5 anos (provisório) | `Identity::RetentionJob` |
| `consent_records` | 5 anos (provisório). O último registro de cada finalidade de uma conta ativa permanece, porque é a prova do que está concedido hoje; o de conta excluída segue o prazo | `Identity::RetentionJob` |
| `outbox_events` e `consumed_events` | 30 dias após a publicação; os eventos pendentes e os mortos permanecem até serem resolvidos ([runbook](../operations/RUNBOOK_OUTBOX.md)) | `Shared::Outbox::CleanupJob` |
| `account_deletions` concluídas | Já guardam só o UUID e as datas, como registro para reaplicar exclusões após restaurar backup; nenhuma rotina as apaga | n/a |

## Exclusão de conta

Fluxo por eventos, com estado acompanhado:

1. A pessoa confirma, com reautenticação. Na mesma transação, as sessões de todos os aparelhos são revogadas, `account_deletions` é criado, e `user.deletion_requested` é publicado. Desde o pedido, a conta não entra, não redefine a senha nem consente.
2. Um job de Identity percorre o registro compartilhado de apagadores (`shared/data_registry`), no qual cada contexto com dados de usuário inscreve o seu `eraser` ao iniciar. Os contextos não chamam Identity, e nem Identity nem `shared/` citam constantes de outros contextos. Cada apagador concluído é marcado em `account_deletions.pending_contexts`, e uma falha repete só o que falta. Eventos da pessoa que cheguem depois do pedido são descartados, exceto `user.deletion_requested`. O prazo é de 24 horas: uma rotina horária enfileira de novo o que não terminou e, passado o prazo, dispara alerta só com o id da exclusão, nunca o e-mail.
3. Fotos são removidas do armazenamento. A integração com o Strava é revogada.
4. Os registros necessários para comprovar conformidade permanecem, sem conteúdo de saúde. O que sobra da conta: a linha de `users` com o mesmo UUID, o e-mail trocado por um valor aleatório, sem senha e com `deleted_at`; `consent_records` e `audit_events` seguem ligados a esse UUID. Para reaplicar exclusões após restaurar backup, guarda-se só o UUID e a data. O mesmo e-mail pode criar outra conta. A revisão jurídica ainda precisa confirmar que esse resíduo é o mínimo necessário.
5. Backups: os dados expiram com a rotação, cujo prazo fica na política. Qualquer restauração reaplica a lista de exclusões antes de voltar ao ar. Operadores: registros do provedor de IA, monitoramento e e-mail seguem a política de cada um, informada na lista de operadores.

O prazo de conclusão é de 24 horas, definido na Fase 02. Um teste automático semeia cada tabela, inclusive campos JSON, com um marcador, e confirma que nada de usuário permanece, salvo os registros mínimos do passo 4.

## Transferência internacional (art. 33)

Enviar fotos a um provedor de IA em outro país é transferência internacional. As hipóteses incluem cláusulas contratuais (II) e consentimento específico e destacado com informação prévia sobre o caráter internacional (VIII).

**Proposta:** informar a transferência na tela de `food_photo_ai`, com operador e região ligados à versão do consentimento, e revisar os termos do provedor na Fase 03. O mesmo vale para hospedagem, armazenamento, e-mail e monitoramento, caso estejam fora do Brasil.

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
