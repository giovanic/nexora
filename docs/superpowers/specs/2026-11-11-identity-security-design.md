# Design — Fase 02: Identity, Security & Privacy

- **Data:** 2026-11-11
- **Estado:** aprovado pelo responsável em 2026-11-11
- **Fase:** [PHASE_02_IDENTITY_SECURITY.md](../../roadmap/phases/PHASE_02_IDENTITY_SECURITY.md). Os critérios `AC-02-01` a `AC-02-13` de lá são a definição de pronto, e este design não os repete.
- **Fontes consultadas em 2026-11-11:** guias do Rails 8.1.4.1 (segurança, autenticação, Active Record Encryption, `rate_limit`, `has_secure_password`), Expo SecureStore do SDK 58 e cheat sheets da OWASP de sessão e de recuperação de senha. Os fatos entram em [EXTERNAL_SOURCES.md](../../architecture/EXTERNAL_SOURCES.md) na Tarefa 1 do plano.

Marcações: **[R]** decisão do responsável; **[E]** escolha de engenharia, sujeita à aprovação deste documento.

## 1. Intenção

Antes de existir qualquer dado de saúde, cada pessoa precisa ter uma conta só dela, entender e controlar o que consente, e conseguir levar ou apagar os próprios dados. Também precisa, desde o primeiro contato, dizer quem é: o que a trouxe ao app e quais esportes pratica, em que nível.

## 2. Primeira entrada no app [R]

Caminho escolhido pelo responsável na conversa de 2026-11-11 ("Conhecer você"):

1. **Criar conta:** e-mail, senha e "tenho 18 anos ou mais". Sem a confirmação, a conta não é criada.
2. **Seus dados:** consentimento `health_data`, obrigatório, com explicação curta e link para a política.
3. **O que te trouxe aqui (opcional, com "pular"):** de uma a quatro opções de lista fechada: começar a me cuidar, ter constância nos treinos, entender minha alimentação, acompanhar minha evolução.
4. **Seus esportes (opcional, com "pular"):** um ou mais, cada um com nível iniciante, intermediário ou avançado.
5. **Pronto:** botão para a câmera. Até a Fase 03, leva a uma tela "em breve".

Sem perguntas sobre peso, medidas ou meta de calorias. Os demais consentimentos (`food_photo_ai`, `strava_integration`, `usage_metrics`) são pedidos quando forem usados, e não no cadastro.

## 3. Objetivos, não objetivos, antiobjetivos

- **Objetivos:** os `AC-02-*` da fase; a primeira entrada acima no mobile; na web, só entrar, sair, consentimentos, exportar e excluir conta.
- **Não objetivos:** login social, dois fatores, verificação de e-mail, painel web completo, provedor real de e-mail (fica para o M1), telas de outras fases.
- **Antiobjetivos:**
  - código próprio de criptografia;
  - token guardado em `localStorage` ou `AsyncStorage`;
  - qualquer resposta de entrada ou de recuperação que revele se um e-mail tem conta (o cadastro é a exceção da seção 4.10);
  - consentimento genérico;
  - dado de usuário em log;
  - exclusão que deixe resto em tabela nova.

## 4. Decisões técnicas [E]

### 4.1 Autenticação (fecha a ADR 0005)

| Item | Escolha | Motivo |
|---|---|---|
| Biblioteca | `has_secure_password` (bcrypt) e código próprio mínimo, seguindo os padrões do gerador de autenticação do Rails. Sem Devise nem Rodauth | O gerador do Rails 8.1 cria sessões no banco, mas só por cookie. Precisamos de cookie na web e token no mobile, sobre o mesmo modelo de sessão |
| Token de sessão | 32 bytes aleatórios (`SecureRandom`), opacos. No banco, só o digest SHA-256 | A OWASP recomenda 128 bits ou mais, e guardar um verificador em vez do token |
| Transporte web | Cookie `__Host-session`, `HttpOnly`, `Secure`, `SameSite=Lax`, assinado. Requisições que alteram estado exigem `Origin` na lista permitida | A API é só API e não usa a proteção CSRF de formulário do Rails |
| Transporte mobile | `Authorization: Bearer`, guardado no SecureStore do Expo (Keychain e Keystore) | Armazenamento seguro do sistema |
| Expiração | Inatividade de 30 dias; prazo absoluto de 90 dias | Risco baixo e app de uso diário |
| Renovação | `POST /api/v1/sessions/refresh` troca o token. O antigo é revogado na mesma transação, com bloqueio na linha | Renovação concorrente: só uma vence, e a outra recebe `401` |
| Revogação | Por dispositivo, e todas as sessões ao trocar a senha | — |
| Senha | Mínimo de 12 caracteres e máximo de 72 bytes, o limite do bcrypt. Sem regra de complexidade | O `has_secure_password` não valida mínimo, e 72 bytes é o limite documentado |
| Recuperação | `has_secure_password reset_token`, com validade de 15 minutos. A resposta é sempre a mesma, exista ou não a conta. Trocar a senha invalida o token e todas as sessões. Não entra automaticamente depois de trocar | Padrão do Rails e da OWASP |
| Limite de tentativas | `rate_limit` do Rails, por IP e por e-mail normalizado, em cadastro, entrada, recuperação e refresh. Armazenado no Valkey como cache | O `rate_limit` usa o cache store configurado |
| E-mail | Action Mailer. Em teste, `:test`; em desenvolvimento, arquivo em `tmp/mails`. O link nunca vai para log | O provedor real é decidido no M1 |

### 4.2 Cifragem (nova ADR 0018)

| Coluna | Tratamento |
|---|---|
| `users.email` | Active Record Encryption **determinística**, normalizada com `strip.downcase`, para permitir busca e índice único |
| `user_profiles.display_name` | Cifragem não determinística |
| `sessions.token_digest` | Hash, sem cifragem |
| `audit_events.ip_hmac` | HMAC com chave própria |
| `consent_records`, `sport_profiles`, motivações | Sem cifragem: listas fechadas, sem texto livre |

As chaves vêm de variáveis de ambiente (`ACTIVE_RECORD_ENCRYPTION_*`), sem `credentials.yml.enc`, que a Fase 01 removeu. Desenvolvimento e teste usam chaves fixas não secretas, só nesses ambientes. Em produção, a ausência das chaves impede a inicialização, pelo `RequiredEnv` existente.

### 4.3 Outbox e registro compartilhado

- **`shared/outbox`:** `outbox_events` gravado na mesma transação; publicador em Sidekiq; `consumed_events` com chave `(consumer, event_id)`; conferência periódica por consumidor, conforme a ADR 0004.
- **`shared/data_registry`:** cada contexto com dados de usuário registra um `exporter` e um `eraser`. Um teste falha se uma tabela com `user_id` não tiver ambos. Isso resolve a contradição registrada na ADR 0003: Identity aciona o registro, e não os contextos.

### 4.4 Exclusão e exportação

- **Reautenticação:** as duas exigem a senha no próprio pedido. Ela é conferida e nunca guardada nem registrada em log.
- **Exportação:** resposta JSON síncrona, com `Cache-Control: no-store`, e nada gravado em disco, o que atende "arquivo privado e de vida curta" sem armazenamento. Basta enquanto os dados forem pequenos. Exportar fotos fica para a Fase 03.
- **Exclusão:**
  - cria `account_deletions`, revoga as sessões e publica `user.deletion_requested` pela outbox, para efeitos externos das fases futuras, como revogar o Strava;
  - um job da Identity percorre os `erasers` do registro em `shared/`. Os contextos se inscrevem no registro ao iniciar, e por isso nem `shared/` nem a Identity citam constantes de outros contextos. Cada apagador concluído fica marcado em `account_deletions.pending_contexts`, e uma falha faz o job tentar de novo, sem repetir os já concluídos;
  - **prazo:** 24 horas. Passado o prazo, um alerta é disparado;
  - **o que sobra:** a linha de `users` permanece com o mesmo UUID, sem e-mail (trocado por um valor aleatório, para manter o `NOT NULL` e o índice único), sem senha e com `deleted_at`. `consent_records` e `audit_events` seguem ligados a esse UUID, sem conteúdo de saúde;
  - **registro para restauração de backup:** só o UUID e a data;
  - **novo cadastro:** o mesmo e-mail pode criar outra conta;
  - eventos de usuário em exclusão são descartados.
- **Documentos a corrigir:** `PRIVACY_AND_LGPD.md` e `DATABASE_DESIGN.md` descrevem os contextos chamando `confirm_deletion`. Passam a descrever o registro acima.

### 4.5 Consentimentos

- **Textos:** versionados no repositório, em `apps/api/config/consents/<finalidade>.v<N>.md`. O app mostra o texto da versão vigente e registra a versão aceita.
- **Aprovação:** **os textos são rascunhos do Claude e precisam da aprovação do responsável** durante a fase, antes do encerramento. A revisão jurídica fica para o M1.
- **Efeitos de revogação nesta fase:** revogar `health_data` leva à tela de exclusão de conta, com confirmação. Se a pessoa cancelar, nada muda e o consentimento continua. As outras finalidades ainda não têm tratamento a interromper.
- **Sem `health_data` ativo:** a conta existe a partir do passo 1, antes do consentimento. Até consentir, a API só permite sessão, consentimentos, exportação, exclusão e saída. Perfil, motivações e esportes respondem `403` com `consent_required`, por um filtro no backend. A primeira entrada recomeça do passo 2 quando a pessoa volta.

### 4.6 Perfil

| Tabela | Campos |
|---|---|
| `user_profiles` | `display_name` opcional, `time_zone` vindo do aparelho, `units` (`metric`), `notification_preferences` (vazio até a Fase 08) e `motivations` (lista fechada, de 0 a 4) |
| `sport_profiles` | Lista fechada inicial de esportes (corrida, caminhada, ciclismo, musculação, natação, outro), com nível, `started_at` e `ended_at`. **Mudar o nível encerra a linha atual e cria outra**, guardando o histórico para as Fases 05 e 06. A unicidade vale para `(user_id, sport)` com `ended_at` nulo |

Novo requisito **FR-PROFILE-004:** a pessoa informa, de forma opcional, o que a trouxe ao app, a partir de uma lista fechada, e pode mudar ou apagar a resposta. Prioridade M1.

### 4.7 Auditoria e logs

- **`audit_events`:** lista fechada de campos por ação. Uma falha de entrada registra só a ação e `ip_hmac`, nunca o e-mail digitado.
- **Logs:** o teste da Fase 01 é ampliado para os fluxos desta fase, incluindo falhas. Sem senha, token, e-mail ou link de recuperação.

### 4.8 Isolamento

- Toda rota de dados parte de `current_user` pela API do contexto.
- Um teste percorre todas as rotas autenticadas e exige um caso de outra pessoa (`404`) para cada uma. Rota nova sem caso faz o teste falhar.

### 4.9 Clientes

- **Mobile (Expo Router):** as cinco telas da primeira entrada, entrar, recuperar senha, e Configurações (perfil, esportes, consentimentos, sessões, sair, excluir conta).
- **Web:** entrar, sair, consentimentos, exportar, excluir conta e a página de redefinir senha. Sem cadastro na web.
- **Exportação só na web:** o mobile mostra o caminho "exporte seus dados pelo site", sem nova dependência de arquivo.
- **Link de recuperação:** aponta para a página de redefinição da web, em `APP_WEB_URL`. Depois de trocar a senha, a pessoa volta ao app e entra.
- **Em ambos:** estados de carregando, vazio e erro; acessibilidade; textos da lista de linguagem.
- **Contrato:** todas as rotas novas ficam em `packages/contracts/openapi.yaml`, com respostas validadas nos request specs.

### 4.10 Escolhas registradas depois da revisão independente [E]

| Ponto | Escolha | Custo se errada |
|---|---|---|
| Cadastro revela e-mail existente | Exceção aceita: sem verificação de e-mail, não há como evitar sem prender a entrada a um e-mail que só existe no M1. Fica com limite de tentativas por IP e mensagem neutra, e entra no relatório como risco | Enumeração de contas pelo cadastro até haver verificação de e-mail |
| Tarefas periódicas | Gem `sidekiq-cron`, para o publicador da outbox, a conferência, a retenção e o alerta de exclusão. O Sidekiq gratuito não agenda, e a hospedagem só é decidida no M1. Manutenção conferida na fonte no plano | Uma dependência a mais, trocável por cron da hospedagem |
| Limite de tentativas no Valkey | Gem `redis`, exigida pelo `:redis_cache_store` do Rails, com cache store configurado em produção | Uma dependência a mais |
| Web e API no mesmo site | Restrição: subdomínios do mesmo domínio, ou proxy na mesma origem. Registrada para a ADR 0015 no M1 | Domínios diferentes exigiriam `SameSite=None` com token CSRF |
| Layout das telas | Livre, seguindo os cinco passos da seção 2 | Ajuste visual depois |

## 5. Restrições

ADR 0002 (versões); ADR 0003 (limites, com o teste já ampliado para toda pasta de `app/`); ADR 0004 (outbox); ADR 0010 (adultos e consentimento por finalidade); regras de produto e de privacidade do `CLAUDE.md`; nenhuma dependência nova sem justificativa no plano. Gems previstas: `bcrypt` (exigida pelo `has_secure_password`), `redis` e `sidekiq-cron`, pelos motivos da seção 4.10.

## 6. O que fica a critério de quem executar

- Nomes internos de classes e serviços, dentro das convenções da Fase 01.
- Ordem das tarefas, desde que a outbox e o registro de dados venham antes da exclusão.
- Layout das telas, seguindo o rascunho aprovado.
