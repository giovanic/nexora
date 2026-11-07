# Requisitos funcionais e não funcionais

Fonte única dos identificadores. Fases e matriz de rastreabilidade só referenciam estes IDs ([matriz](../roadmap/TRACEABILITY.md)).

**Prioridade:** `M1` (necessário para o beta fechado), `Lançamento`, `Pós-lançamento`.

Os valores numéricos de desempenho são metas iniciais de engenharia, a validar com medição real na fase indicada no documento de cada fase.

## Identidade e acesso

| ID | Requisito | Prioridade |
|---|---|---|
| FR-ID-001 | A pessoa cria conta com e-mail e senha somente após confirmar ter 18 anos ou mais; sem essa confirmação a conta não é criada. | M1 |
| FR-ID-002 | A pessoa entra, sai e renova a sessão; a sessão expira e pode ser revogada por dispositivo. | M1 |
| FR-ID-003 | A pessoa recupera a senha por link de uso único com prazo de validade. | M1 |
| FR-ID-004 | A pessoa exclui a própria conta sem intermediação, e os dados são apagados ou anonimizados conforme a política de retenção. | M1 |
| FR-ID-005 | A pessoa exporta os próprios dados em formato estruturado, sem custo. | M1 |
| FR-ID-006 | Toda consulta e alteração de dados é limitada ao dono; acesso a recurso de outra pessoa responde como inexistente. | M1 |
| FR-ID-007 | Os consentimentos são registrados por finalidade, com versão do texto e data, antes de qualquer tratamento que dependa deles. | M1 |
| FR-ID-008 | A pessoa revoga qualquer consentimento com a mesma facilidade com que o concedeu, e o tratamento correspondente é interrompido. | M1 |

## Perfil

| ID | Requisito | Prioridade |
|---|---|---|
| FR-PROFILE-001 | A pessoa mantém dados de perfil e preferências de fuso horário, unidades e notificações. | M1 |
| FR-PROFILE-002 | A pessoa informa um ou mais esportes, com nível de experiência em cada um: iniciante, intermediário ou avançado. | M1 |
| FR-PROFILE-003 | Alterar esporte ou nível vale daí em diante e não reescreve o histórico de metas e XP. | Lançamento |

## Alimentação por foto

| ID | Requisito | Prioridade |
|---|---|---|
| FR-FOOD-001 | No mobile, a pessoa fotografa a refeição ou escolhe da galeria, e o envio usa autorização emitida pelo backend. | M1 |
| FR-FOOD-002 | O envio valida tipo e tamanho do arquivo, e a foto fica em armazenamento privado, acessível só por URL assinada de prazo curto. | M1 |
| FR-FOOD-003 | A análise roda de forma assíncrona, com os estados pendente, processando, concluída e falha, visíveis ao usuário, e permite nova tentativa. | M1 |
| FR-FOOD-004 | A análise identifica alimentos e preparações prováveis, com um nível de confiança por item. | M1 |
| FR-FOOD-005 | A análise estima a porção de cada item como faixa em gramas, com descrição em medida caseira. | M1 |
| FR-FOOD-006 | O sistema calcula calorias e macronutrientes como faixa (mínimo, provável, máximo), com a origem dos dados nutricionais de cada item. | M1 |
| FR-FOOD-007 | A pessoa confirma a estimativa com uma única ação. | M1 |
| FR-FOOD-008 | A pessoa corrige item ou porção; o sistema recalcula e preserva a estimativa original no histórico da análise. | M1 |
| FR-FOOD-009 | A pessoa consulta o histórico de refeições por dia, com paginação. | M1 |
| FR-FOOD-010 | A pessoa apaga uma refeição, e a foto associada é removida do armazenamento. | M1 |
| FR-FOOD-011 | A pessoa registra uma refeição manualmente, quando não há foto ou quando a análise falha. | M1 |
| FR-FOOD-012 | Foto sem comida ou ilegível produz uma mensagem clara e nenhuma estimativa inventada. | M1 |
| FR-FOOD-013 | O provedor de IA é trocado por configuração e adaptador novo, sem alterar o domínio Nutrition. | M1 |
| FR-FOOD-014 | Toda análise registra versão do prompt, provedor, modelo, resultado bruto validado e custo. | M1 |
| FR-FOOD-015 | Existe um dataset de avaliação com métricas reproduzíveis, executado ao trocar prompt, modelo ou provedor. | M1 |

## Catálogo de alimentos

| ID | Requisito | Prioridade |
|---|---|---|
| FR-CATALOG-001 | Cada item do catálogo registra base de origem, versão, identificador na origem e licença. | M1 |
| FR-CATALOG-002 | Pratos brasileiros são compostos de ingredientes, com receita-base declarada e indicação de que são composição própria. | M1 |
| FR-CATALOG-003 | A pessoa busca alimentos no catálogo ao corrigir uma refeição. | M1 |
| FR-CATALOG-004 | Nenhuma base é carregada sem licença verificada e decisão registrada em ADR. | M1 |

## Atividades

| ID | Requisito | Prioridade |
|---|---|---|
| FR-ACT-001 | A pessoa registra manualmente uma atividade com tipo, data e duração, e opcionalmente distância e elevação. | Lançamento |
| FR-ACT-002 | A pessoa consulta o histórico de atividades com filtro por período e tipo, e paginação. | Lançamento |
| FR-ACT-003 | Cada atividade guarda a origem, e a mesma atividade externa nunca aparece duplicada. | Lançamento |

## Integração com Strava

| ID | Requisito | Prioridade |
|---|---|---|
| FR-STRAVA-001 | A pessoa conecta a conta por OAuth 2.0 com o escopo mínimo definido em ADR, e o sistema trata o caso de o atleta conceder menos escopos que os pedidos. | Lançamento |
| FR-STRAVA-002 | Tokens são guardados cifrados, renovados antes de expirar, e o novo refresh token substitui o anterior de forma atômica. | Lançamento |
| FR-STRAVA-003 | O endpoint de webhook conclui a validação oficial e confirma cada evento em até 2 segundos, processando depois de forma assíncrona. | Lançamento |
| FR-STRAVA-004 | Evento de criação importa a atividade com tipo, duração, distância, elevação e demais dados autorizados. | Lançamento |
| FR-STRAVA-005 | Evento de atualização atualiza a atividade local. | Lançamento |
| FR-STRAVA-006 | Evento de exclusão remove a atividade local e dispara `activity.deleted`. | Lançamento |
| FR-STRAVA-007 | Ao conectar, uma sincronização inicial importa o histórico autorizado, em lotes, dentro do orçamento de requisições. | Lançamento |
| FR-STRAVA-008 | Reprocessar o mesmo evento não cria duplicidade nem altera o resultado. | Lançamento |
| FR-STRAVA-009 | As chamadas respeitam os limites por janela e por dia, leem os headers e adiam o trabalho ao receber 429. | Lançamento |
| FR-STRAVA-010 | Uma reconciliação periódica detecta e corrige divergências de eventos perdidos. | Lançamento |
| FR-STRAVA-011 | A pessoa desconecta a conta; o sistema revoga o acesso no Strava e apaga os tokens e os dados importados. | Lançamento |
| FR-STRAVA-012 | Quando o atleta revoga o acesso pelo Strava, o webhook dispara o mesmo apagamento da desconexão. | Lançamento |
| FR-STRAVA-013 | Dados vindos do Strava só são exibidos ao próprio dono, e as telas seguem as diretrizes de marca. | Lançamento |

## Metas

| ID | Requisito | Prioridade |
|---|---|---|
| FR-GOALS-001 | A pessoa cria e edita metas diárias de hábito a partir de um catálogo de tipos permitidos. | M1 |
| FR-GOALS-002 | A pessoa faz check-in manual de cada meta do dia, respeitando o próprio fuso horário. | M1 |
| FR-GOALS-003 | Progresso e conclusão seguem regras determinísticas e versionadas: os mesmos check-ins sempre produzem o mesmo resultado. | M1 |
| FR-GOALS-004 | A pessoa consulta o histórico de metas e check-ins. | M1 |
| FR-GOALS-005 | O sistema não aceita metas de calorias, déficit, peso ou compensação de comida com exercício; a tentativa pela API é rejeitada. | M1 |
| FR-GOALS-006 | A pessoa define metas semanais e planeja as atividades da semana. | Lançamento |
| FR-GOALS-007 | Metas de atividade podem ser confirmadas automaticamente por atividades importadas. | Lançamento |
| FR-GOALS-008 | Dias de recuperação planejados contam a favor da consistência, e as metas se adaptam a mudanças de rotina sem punição. | Lançamento |
| FR-GOALS-009 | O sistema sugere metas de acordo com esporte e nível de experiência. | Lançamento |

## Gamificação

| ID | Requisito | Prioridade |
|---|---|---|
| FR-GAME-001 | XP é gerado somente a partir de eventos de domínio, por regras versionadas. | Lançamento |
| FR-GAME-002 | Toda concessão fica em livro-razão de inclusão apenas, e o mesmo evento nunca gera XP duas vezes para a mesma regra. | Lançamento |
| FR-GAME-003 | O nível é derivado do XP acumulado por uma curva versionada e pode ser recalculado a partir do livro-razão. | Lançamento |
| FR-GAME-004 | Missões são atribuídas de acordo com esporte e nível de experiência. | Lançamento |
| FR-GAME-005 | A conclusão de missão é validada a partir de eventos, e nunca por declaração do cliente. | Lançamento |
| FR-GAME-006 | Conquistas são desbloqueadas uma única vez por pessoa, por regra versionada. | Lançamento |
| FR-GAME-007 | Sequências de consistência contam dias de recuperação e têm tolerância definida, sem punir um dia perdido com a perda total. | Lançamento |
| FR-GAME-008 | XP de atividade tem teto diário e semanal, e volume acima do teto não gera mais pontos. | Lançamento |
| FR-GAME-009 | Excluir o evento de origem gera lançamento de estorno no livro-razão, sem apagar o histórico. | Lançamento |
| FR-GAME-010 | Nenhuma regra usa calorias consumidas ou queimadas, déficit, peso ou volume absoluto como critério, e uma verificação automática impõe isso. | Lançamento |
| FR-GAME-011 | A pessoa consulta o histórico de XP, recompensas e conquistas, com o motivo de cada lançamento. | Lançamento |
| FR-GAME-012 | Ganho de XP, subida de nível e conquistas têm retorno visual no mobile e na web. | Lançamento |
| FR-GAME-013 | Desafios com prazo e recompensas virtuais seguem as mesmas regras de concessão e de segurança. | Lançamento |

## Notificações

| ID | Requisito | Prioridade |
|---|---|---|
| FR-NOTIF-001 | Cada tipo de notificação é opcional, configurável, e respeita horário de silêncio no fuso da pessoa. | Lançamento |
| FR-NOTIF-002 | O mobile recebe notificações de missões, metas e relatórios, e é possível ver as mesmas mensagens no app. | Lançamento |
| FR-NOTIF-003 | O envio é idempotente, e a mesma notificação não é entregue duas vezes por reprocessamento. | Lançamento |

## Evolução e inteligência

| ID | Requisito | Prioridade |
|---|---|---|
| FR-PROG-001 | A pessoa vê a própria evolução: consistência, sequências, recordes e comparações de um catálogo fechado, só de constância, sem totais ou tendências de calorias. | Lançamento |
| FR-PROG-002 | A pessoa recebe um relatório semanal baseado apenas nos próprios dados registrados. | Lançamento |
| FR-PROG-003 | Insights e recomendações indicam em quais dados se baseiam e têm volume mínimo de dados para aparecer. | Lançamento |
| FR-PROG-004 | Missões podem ser personalizadas pelos padrões de consistência da pessoa. | Pós-lançamento |

## Painel web

| ID | Requisito | Prioridade |
|---|---|---|
| FR-WEB-001 | O painel oferece visão geral e calendário de refeições, metas e atividades. | Lançamento |
| FR-WEB-002 | O painel oferece histórico alimentar e de atividades, com os mesmos dados do mobile. | Lançamento |
| FR-WEB-003 | O painel mostra XP, nível, sequências, metas, missões e conquistas. | Lançamento |
| FR-WEB-004 | O painel oferece configurações, incluindo privacidade, exportação e exclusão de conta. | Lançamento |
| FR-WEB-005 | O painel mostra evolução e relatórios semanais. | Lançamento |

## Aplicativo móvel

| ID | Requisito | Prioridade |
|---|---|---|
| FR-MOBILE-001 | O app oferece as telas do beta: entrada, consentimentos, câmera, resultado da análise, histórico e metas do dia. | M1 |
| FR-MOBILE-002 | O app trata permissão de câmera negada e falha de rede sem perder a foto já capturada. | M1 |
| FR-MOBILE-003 | O app permite conectar o Strava e consultar atividades. | Lançamento |
| FR-MOBILE-004 | O app mostra XP, nível, sequências, missões e conquistas. | Lançamento |

## Requisitos não funcionais

### Segurança

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-SEC-001 | Tokens de integração e de aparelho ficam cifrados em nível de aplicação, e as demais colunas seguem as classes de dado decididas em ADR na Fase 02. | M1 |
| NFR-SEC-002 | URLs de foto são assinadas, com validade de no máximo 15 minutos, e nunca aparecem em logs. | M1 |
| NFR-SEC-003 | Endpoints de autenticação têm limite de tentativas. | M1 |
| NFR-SEC-004 | O CI roda análise estática de segurança e auditoria de dependências em Ruby e JavaScript, e falha em achado alto. | M1 |
| NFR-SEC-005 | Nenhum segredo fica versionado, e o CI verifica isso. | M1 |
| NFR-SEC-006 | Ações sensíveis ficam em trilha de auditoria: login, consentimento, exportação, exclusão, conexão e desconexão de integração. | M1 |
| NFR-SEC-007 | Webhooks externos validam a origem conforme o mecanismo disponível e nunca confiam no conteúdo sem revalidar na API. | Lançamento |

### Privacidade

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-PRIVACY-001 | Fotos só são enviadas à IA após consentimento específico e destacado, que informa a transferência internacional quando existir. | M1 |
| NFR-PRIVACY-002 | Os direitos do art. 18 da LGPD têm fluxo implementado ou documentado, sem custo para o titular. | M1 |
| NFR-PRIVACY-003 | Cada categoria de dado tem prazo de retenção definido e aplicado por rotina automática. | M1 |
| NFR-PRIVACY-004 | Logs, métricas e relatórios de erro não contêm fotos, conteúdo de refeições, tokens nem dados de saúde identificáveis. | M1 |
| NFR-PRIVACY-005 | Só são usados provedores de IA cuja política documentada não usa as entradas para treinamento. | M1 |
| NFR-PRIVACY-006 | Dados do Strava não são enviados a provedores de IA até reavaliação registrada em ADR. | Lançamento |
| NFR-PRIVACY-007 | Métricas de uso só são coletadas com consentimento próprio. | M1 |
| NFR-PRIVACY-008 | Há registro das operações de tratamento e encarregado com contato público antes de haver usuários reais. | M1 |

### Segurança de saúde

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-SAFETY-001 | Toda estimativa nutricional é armazenada e exibida como estimativa, com faixa e confiança, nunca como medição. | M1 |
| NFR-SAFETY-002 | Textos do produto, da IA e de notificações seguem a lista de linguagem proibida, e há verificação automática dos textos estáticos. | M1 |
| NFR-SAFETY-003 | O produto não oferece diagnóstico, tratamento nem prescrição, e respostas de IA são restritas a esse limite. | M1 |
| NFR-SAFETY-004 | Calorias nunca aparecem em comparação com um limite, em cores de alerta, como algo a reduzir, ou em totais e tendências entre períodos. | M1 |
| NFR-SAFETY-005 | Qualquer suporte a menores exige ADR própria e o modo específico descrito em [segurança de dados de saúde](../security/HEALTH_DATA_SAFETY.md). | Pós-lançamento |

### Desempenho

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-PERF-001 | Endpoints de leitura têm p95 de até 300 ms, sem contar a análise de IA. | Lançamento |
| NFR-PERF-002 | A análise de foto termina com p95 de até 60 segundos. | M1 |
| NFR-PERF-003 | Listagens são sempre paginadas, e consultas não têm N+1, verificado em testes. | M1 |
| NFR-PERF-004 | Uma meta de capacidade para o lançamento é definida e validada por teste de carga. | Lançamento |

### Observabilidade

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-OBS-001 | Logs são estruturados e têm identificador de correlação entre requisição, job e evento. | M1 |
| NFR-OBS-002 | Erros de backend e dos clientes são capturados em uma ferramenta de monitoramento. | M1 |
| NFR-OBS-003 | Há métricas e alertas para filas, outbox, webhooks e falhas de análise. | Lançamento |
| NFR-OBS-004 | Health checks separam processo vivo de dependências prontas. | M1 |

### Acessibilidade

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-A11Y-001 | O painel web atende WCAG 2.2 AA nos fluxos principais, verificado por ferramenta automática e revisão manual. | Lançamento |
| NFR-A11Y-002 | O app móvel funciona com leitor de tela nos fluxos principais, com rótulos e áreas de toque adequadas. | Lançamento |

### Custo

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-COST-001 | O custo de cada análise é registrado e pode ser agregado por usuário e por período. | M1 |
| NFR-COST-002 | Existe um limite configurável de análises por usuário e por período, com mensagem clara ao atingi-lo. | M1 |
| NFR-COST-003 | Um alerta dispara quando o gasto total de IA passa de um valor configurado. | M1 |

### Operação

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-OPS-001 | Todos os serviços sobem localmente com comandos documentados e testados a partir de um clone limpo. | M1 |
| NFR-OPS-002 | O CI executa testes, lint e tipos de todas as aplicações, além do verificador do harness. | M1 |
| NFR-OPS-003 | Backups são automáticos, e a restauração é testada e registrada. | M1 |
| NFR-OPS-004 | O deploy é reproduzível e tem caminho documentado de reversão. | M1 |
| NFR-OPS-005 | Ativação e retenção são medidas conforme as definições do PRD. | M1 |
| NFR-OPS-006 | Migrations são reversíveis quando possível e rodam sem interromper o serviço no lançamento. | Lançamento |

### Harness

| ID | Requisito | Prioridade |
|---|---|---|
| NFR-HARNESS-001 | `scripts/verify-harness.sh` retorna diferente de zero em qualquer falha crítica, e essa propriedade é testada. | M1 |
| NFR-HARNESS-002 | Uma sessão nova do Claude Code entende produto, estado e próximo passo só com o que o `CLAUDE.md` indica. | M1 |
| NFR-HARNESS-003 | Toda mudança de estado de fase tem data e evidência, e nenhuma fase avança sem autorização do responsável. | M1 |
| NFR-HARNESS-004 | Todo requisito é rastreável até fase e critério de aceite, e, ao concluir a fase, até implementação e teste. | M1 |
