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
| `health_data` | Todo o tratamento, porque é a função do produto | Tela explica e leva à exclusão de conta, após confirmação. A revisão jurídica confirma esse destino |

**Estado na Fase 02:** só existe a Identity. Revogar `health_data` responde `409 deletion_required` e o consentimento continua, até a pessoa confirmar a exclusão da conta. As outras finalidades já podem ser concedidas e revogadas, com registro e evento `consent.revoked`, mas ainda não têm tratamento a interromper.

Toda fase que cria um novo tratamento atualiza esta tabela e testa a interrupção.

## Direitos do titular (art. 18)

Gratuitos (§5).

| Direito | Fluxo | Fase |
|---|---|---|
| Confirmação e acesso (I, II) | Telas do app e exportação | 02 |
| Correção (III) | Edição de perfil e correção de refeições | 02, 03 |
| Anonimização, bloqueio ou eliminação do desnecessário (IV) | Rotinas de retenção; contato com o encarregado | 02 |
| Portabilidade (V) | Exportação em formato estruturado | 02 |
| Eliminação de dados com consentimento (VI) | Exclusão de refeição e de conta | 02, 03 |
| Informação sobre compartilhamento (VII) | Política de privacidade, com lista de operadores | M1 |
| Informação sobre não consentir (VIII) | Texto das telas de consentimento | 02 |
| Revogação (IX) | Tela de privacidade | 02 |

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
