# Relatório da Fase 02 — Identity, Security & Privacy

- **Data:** 2026-11-13
- **Estado:** `Em revisão`, aguardando aprovação do responsável
- **Branch:** `phase/02-identity-security`, sem push nem PR (aguardando autorização)

## 1. Resumo

Cada pessoa acessa sua conta e somente seus dados, com consentimento por finalidade, exportação e exclusão funcionando, antes de existir qualquer dado de saúde:

- **Outbox e registro de dados (`shared`):** `outbox_events` e `consumed_events` com implementação própria mínima, publicador, conferência por consumidor, limpeza e [runbook de evento morto](../../operations/RUNBOOK_OUTBOX.md). O registro compartilhado de exportadores e apagadores obriga todo contexto novo a declarar como exporta e como apaga.
- **Identity & Access:** cadastro com confirmação de 18 anos (também no banco), sessões por dispositivo com renovação e revogação, recuperação de senha de uso único, consentimentos por finalidade com versão e histórico, exportação, exclusão acompanhada até a conclusão por contexto, retenção, auditoria com lista fechada de campos e cifragem em nível de aplicação.
- **User Profile:** perfil, perfil esportivo com nível por esporte e motivações.
- **Contrato da API** atualizado em `packages/contracts`.
- **Mobile:** entrada, cadastro, consentimento, motivações, esportes, configurações (perfil, consentimentos, sessões, conta).
- **Web mínima:** entrada, exportação, exclusão, consentimentos e redefinição de senha.
- **ADRs:** 0005 e 0018 `Aceita` conforme o plano aprovado; 0004 com evidência, ainda `Proposta`; 0010 intacta.

O visual das telas ficou sem tratamento, por sua decisão (Fase 07).

## 2. Validação

Execuções do controlador em 2026-11-13, no commit `6b832a4`.

| Comando | Código | Resultado |
|---|---|---|
| `bundle exec rspec` | 0 | 593 exemplos, 0 falhas |
| `bundle exec rubocop` | 0 | 161 arquivos, sem ofensas |
| `bundle exec brakeman -q --no-pager -w2` | 0 | Nenhum aviso |
| `bundle exec bundle-audit check --update` | 0 | Nenhuma vulnerabilidade |
| `npm run check -w @app/contracts` | 0 | Tipos gerados conferem |
| `npm audit --audit-level=high` | 0 | Nenhum alerta alto ou crítico; 32 moderados e 1 baixo em ferramentas de desenvolvimento |
| Web: typecheck, lint, testes, build | 0, 0, 0, 0 | 67 testes |
| Mobile: typecheck, lint, testes | 0, 0, 0 | 98 testes |
| `bash scripts/verify-harness.sh` | 0 | Aprovado |
| `bash scripts/test-verify-harness.sh` | 0 | 93 testes |
| Gitleaks e CI do PR | não executado | Roda no CI após o push, que aguarda autorização |

**Demonstrações reais.** Só contas fictícias (`example.test`), sem dado real. Capturas em [`evidence/phase-02/`](evidence/phase-02/).

- **Mobile:** emulador Android Pixel_10, Expo Go, contra a API local. Fluxo: cadastro, consentimento de `health_data`, motivações, esportes, pronto, "em breve", configurações (perfil, consentimentos, sessões, conta), sair, entrar de novo. Capturas `mobile-01` a `mobile-12`. Observado: Markdown cru no texto de consentimento, caixas `[ ]` em texto, 18 linhas de esportes nas configurações e fuso "GMT" (o do emulador).
- **Web:** Chromium real via Playwright, contra a API local pelo proxy do Vite (capturas `web-01` a `web-11`; não existe `web-07`).
  - Cookie `__Host-session` com `HttpOnly`, `Secure`, `Lax` e `path=/`; `localStorage` e `sessionStorage` vazios.
  - Senha errada na exportação mantém a sessão. A exportação baixa `meus-dados-*.json` com `identity`, `shared` e `user_profile`, sem digest nem `ip_hmac`.
  - Sair remove o cookie. `/reset-password` remove o fragmento da URL, tem `no-referrer`, e o token inválido mostra mensagem.
  - Exclusão de conta desconecta; o backend conclui (`pending []`, `completed`) e a conta não entra mais (401).
  - Redefinição de senha concluída com o token real lido do e-mail em `tmp/mails` (204, "Senha alterada"), e entrada com a senha nova.
  - Revogação de `health_data` com a confirmação aprovada mostra "Retirado". No backend: 0 esportes, motivações `[]`, nome de exibição nulo, fuso mantido, `health_data` não concedido.
- **Falhas do roteiro:** a primeira tentativa do reset falhou por erro do roteiro (e-mail em quoted-printable sem decodificar), não do app.

## 3. Critérios

| Critério | Evidência | Situação |
|---|---|---|
| `AC-02-01` | `spec/requests/registrations_spec.rb`, `spec/domains/identity/user_spec.rb` (constraint do banco) | Comprovado |
| `AC-02-02` | `spec/requests/sessions_spec.rb` (inclui renovação concorrente), `spec/domains/identity/session_device_label_spec.rb`, testes do mobile e da web; demonstração mobile-11/12 e web-01/02/05 | Comprovado. iOS e aparelho físico não testados |
| `AC-02-03` | `spec/requests/password_resets_spec.rb`; demonstração web-06 e web-09 | Comprovado |
| `AC-02-04` | `spec/integration/account_deletion_scan_spec.rb` (marcador em cada tabela, JSON incluído, tabela nova sem tratamento), `spec/requests/account_deletion_spec.rb`, `spec/domains/identity/deletion_delivery_race_spec.rb`; demonstração web-08 | Comprovado |
| `AC-02-05` | `spec/requests/account_export_spec.rb` (duas contas), `spec/domains/shared/data_registry_coverage_spec.rb`; demonstração web-03/04 | Comprovado. O texto do critério diz "arquivo privado e de vida curta", e o desenho gera a exportação na hora, sem arquivo (R23) |
| `AC-02-06` | `spec/requests/isolation_spec.rb`, `spec/contract/routes_spec.rb`, `spec/requests/internal_routes_spec.rb` | Comprovado |
| `AC-02-07` | `spec/requests/consents_spec.rb`, `spec/domains/identity/consents_spec.rb`, `spec/domains/user_profile/revocation_race_spec.rb`; demonstração: mobile-03/04/10 e revogação de `health_data` na web (web-10, web-11) com a conferência no backend | **Parcial:** os quatro textos de consentimento (`apps/api/config/consents/*.v1.md`) aguardam sua aprovação e não têm revisão jurídica |
| `AC-02-08` | `spec/domains/user_profile/profile_spec.rb`, `spec/requests/profiles_spec.rb` (inclui trocar e limpar motivações), testes do mobile | **Parcial.** FR-PROFILE-001: preferências de notificação não são expostas até a Fase 08 (R22) e unidades só `metric` no MVP. FR-PROFILE-003: metas e XP ainda não existem, então a regra de não reescrever histórico só é provada para o histórico de níveis |
| `AC-02-09` | `spec/requests/sessions_spec.rb`, `registrations_spec.rb`, `password_resets_spec.rb` (429), `spec/domains/identity/user_spec.rb` (cifragem), `spec/domains/identity/record_audit_spec.rb` | Comprovado |
| `AC-02-10` | Tabela de direitos em [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md), `spec/domains/identity/retention_job_spec.rb`, `spec/domains/shared/outbox/` | Comprovado como fluxo técnico. Adequação jurídica não verificada |
| `AC-02-11` | ADRs [0005](../../architecture/decisions/0005-authentication-strategy.md) e [0018](../../architecture/decisions/0018-application-level-encryption.md) `Aceita`, com evidência; [0004](../../architecture/decisions/0004-domain-events-transactional-outbox.md) com evidência e `Proposta` | **Aguarda você:** as ADRs 0005 e 0018 foram marcadas `Aceita` pelo plano aprovado, e peço confirmação explícita. A 0004 está pronta para aceitação |
| `AC-02-12` | `spec/integration/deletion_requested_delivery_spec.rb` (falha injetada, reprocessamento sem duplicar, conferência acusa consumidor faltante), `spec/domains/shared/outbox_spec.rb` | Comprovado |
| `AC-02-13` | `spec/integration/logging_spec.rb` | Comprovado para `log/test.log`. O log do Sidekiq não é coberto pelo spec |

## 4. Revisões

Nenhum achado crítico ou importante em aberto. A branch inteira passou por `software-architect`; backend e segurança foram revistos nas tarefas 1 a 9, e a segurança revisou também os clientes e os documentos.

| Revisão | Achados importantes | Tratamento |
|---|---|---|
| Tarefa 0 (docs) | Documentos ainda diziam "referência anonimizada" e citavam `confirm_deletion` | Corrigido (1 rodada) |
| Tarefa 1 (chaves, ambiente) | Limpa | Minors adiados |
| Tarefa 2 (outbox) | Falha de enqueue após commit virava 500; exceção em regra de descarte travava a outbox | Corrigido (1 rodada) |
| Tarefa 3 (sessões) | Limpa | Minors adiados; trusted proxies vai para a hospedagem |
| Tarefa 4 (reset de senha) | Limpa | Minors adiados; `error_message` do Sidekiq antes do e-mail real |
| Tarefa 5 (consentimentos) | Limpa | Versão vigente exigida na Fase 03 (depois tratada, ver abaixo); textos aguardam você |
| Tarefa 6 (perfil) | Migration irreversível; `motivations` como `varchar[]` em vez de `text[]` | Corrigido (1 rodada) |
| Tarefa 7 (exportação) | Limpa | Minors adiados |
| Tarefa 8 (exclusão) | Limpa; o controlador achou o dump instável das CHECKs em `schema.rb` | Corrigido (2 rodadas) |
| Tarefa 9 (isolamento, logs, retenção) | `accounts#destroy` não comparava A após o apagamento real; enumeração de rotas isentava controllers inteiros | Corrigido (1 rodada) |
| `security-reviewer` e `backend-reviewer`, tarefas 1–9 | Segurança: 3 importantes (reautenticação sem limite por conta nem auditoria; revogar `health_data` exigia excluir a conta; textos sem prazos, controlador e transferência internacional) e 10 minors. Backend: 1 importante (consentimento ignora a versão aceita) e 9 minors | Quatro rodadas de correção, com nova revisão a cada uma, e três importantes novos achados e corrigidos no caminho: limite de e-mail com leitura antes do incremento, consumidor de revogação apagando dado novo (R34), `CleanupJob` apagando evento morto (R36). Revogar `health_data` por decisão sua (R32, R33). **Recusado:** FK `user_profiles`→`users`, que o [DATABASE_DESIGN.md:11](../../architecture/DATABASE_DESIGN.md) permite. Adiados: ver 6(e) |
| `frontend-mobile-reviewer`, tarefa 10 | Sem caminho para excluir a conta sem `health_data`; sessões indistinguíveis | Corrigido (1 rodada) |
| `frontend-mobile-reviewer`, tarefa 11 e revisão conjunta 10+11 | Web ignorava falha ao sair; sem foco nem região viva no consentimento e na revogação; 200 não JSON quebrava a página; `outdated_version`, rótulos de estado e mensagem de senha errada diferentes entre os clientes | Corrigido (1 rodada nos dois clientes) |
| `software-architect`, tarefa 12 (docs) | ADR 0018 dizia que o Active Record aceita chaves anteriores, mas a fonte registrada diz que a rotação não é suportada na coluna determinística; Marco Civil sem fonte | Corrigido (2 rodadas) |
| `software-architect`, branch inteira (fechamento) | I-1 `sport_profile.changed` com esporte e nível no payload; I-2 ADR 0004 com frases vencidas; I-3 checagem de limites sem `config/initializers`; I-4 corrida consumidor×apagador | Corrigido e re-revisto: I-4 por R40; ADR 0004 pronta para aceitação. M-2 (Strava), M-3 (Fase 05) e M-5 adiados |
| `security-reviewer`, delta `95ee164..32f5398` | 0 críticos, 0 importantes. Minors: `signOut` mobile limpa o token sem resposta do servidor; sessão órfã se o SecureStore falha; `http://` fora de `__DEV__` e `allowBackup`; sem CSP | Adiados, ver 6(c) e 6(e) |
| `qa-reviewer` (fechamento) | Podia ir a `Em revisão`. Lacunas: relatório; sem spec de mudar e limpar motivações; `all_sessions_revoked` sem asserção; demos de reset e revogação; matriz | Specs, asserção e matriz corrigidos; demos feitas; relatório é este documento |

## 5. Verificado e apenas criado

- **Verificado por execução:** todos os comandos da seção 2; as demonstrações no emulador e no Chromium, com conferência no backend; o runbook da outbox, executado no banco de teste (inspecionar, reenfileirar, resolver à mão); a migração e o `rollback` em banco temporário; o `schema.rb` idêntico entre `migrate`, `schema:load` e o versionado.
- **Verificado só no emulador:** o app mobile. iOS e aparelho físico não testados.
- **Apenas criado, nunca exercido:**
  - Provedor de e-mail de produção: não configurado. O e-mail de reset só foi lido em `tmp/mails`.
  - Sentry com envio real: continua pendente desde a Fase 01 (lacuna de `AC-01-07`).
  - Procedimento de rotação de chaves e recriptografia: não existe.
  - Trusted proxies e `remote_ip`: não configurados.
  - Log do Sidekiq: fora do `logging_spec`.
  - Textos de consentimento: rascunhos, sem aprovação nem revisão jurídica.
  - Gitleaks: só roda no CI do PR.

## 6. Pendências

**(a) Decisões suas**

1. Aprovar os quatro textos de consentimento v1 (`apps/api/config/consents/*.v1.md`).
2. Aceitar a ADR 0004.
3. Confirmar as ADRs 0005 e 0018, marcadas `Aceita` pelo plano aprovado.
4. Autorizar o push e o PR.

**(b) Revisão jurídica (M1).** Nada aqui é parecer jurídico.

- Revogação de `health_data`: o desenho (apaga esportes, níveis, motivações e nome; mantém fuso e unidades; a conta continua) e o critério de anonimização do que fica.
- Informação do art. 9 nos textos de consentimento: controlador, encarregado, prazos, transferência internacional.
- Marco Civil (art. 15), sem verificação na fonte, contra o `ip_hmac` não reversível de `audit_events`.
- Retenção de 5 anos provisória e a exceção R31: em conta ativa, guarda-se o último consentimento por finalidade além do prazo.
- Evento morto da outbox sem prazo máximo de retenção.
- Risco de enumeração por `email_taken` no cadastro, aceito no desenho. Não existe lacuna aceita registrada.
- Demais itens de [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md), seção "Pendências para a revisão jurídica" (1 a 15).

**(c) Antes do M1**

- `error_message` do Sidekiq pode levar o e-mail ao Valkey: re-lançar com mensagem fixa em `PasswordResetJob` antes de ligar o provedor de e-mail.
- Cooldown silencioso no reset por e-mail (hoje 20 por hora por e-mail).
- Rotação e recriptografia de `users.email`.
- CSP e `frame-ancestors` para o host web.
- Trusted proxies e `request.remote_ip` atrás do proxy; log de proxy com o token no caminho do reset (Fase 09).
- Limites de tentativa falham abertos se o Redis cair.
- Sentry com envio real e revisão jurídica do operador.

**(d) Próximas fases**

- **Fase 03:** o consentimento já só vale na versão vigente do texto; a Fase 03 cria a v2 do texto `food_photo_ai` com provedor e país e confere `food_photo_ai` antes de enviar qualquer foto. Todo contexto com dado de saúde deve assinar `consent.revoked`; não há spec que garanta isso.
- **Fase 04:** o Strava revoga o acesso depois do apagador; a ordem precisa ser revogar antes de apagar (M-2).
- **Fase 05:** `EraseHealthData` não publica `sport_profile.changed` (M-3).
- **Fase 07:** identidade visual, por sua decisão: Markdown cru no texto de consentimento, caixas `[ ]` em texto, níveis como linhas, lista de 18 esportes nas configurações, fuso exibido como identificador cru, web sem estilo.
- **Fase 08:** preferências de notificação (R22).

**(e) Menores registrados e adiados**

- **Ambiente e chaves:** `APP_WEB_URL` marcado como segredo no documento de variáveis; `ENV.fetch` com valor vazio; spec do cache confere só a classe; justificativa das gems só no plano.
- **Outbox:** tentativas contadas por evento e não por consumidor (R14); formato do nome de evento com e sem dígitos; evento morto sem reprocessamento automático (só pelo runbook); efeitos dentro da transação com lock sem timeout; `record_failure` pode travar o lote se o banco falhar; sem índice de retenção (medir antes); `discard_if` consulta `account_deletions` e trava a linha de `users` por evento (R40).
- **Sessões e autenticação:** `Retry-After` sempre a janela inteira; `last_used_at` gravado a cada requisição; cookie com UUID em maiúsculas não limpo; sair pode perder corrida com refresh; refresh escolhe o transporte pelos headers; `GET /sessions` sem cursor; `device_label` cortado em silêncio; refresh sem janela de tolerância; reuso de token renovado; aviso de troca de senha; 429 ocupa vaga no limite.
- **Reset e logs:** `FilteredPath` usa `gsub` no caminho inteiro; validação dupla no reset; spec concorrente com `sleep 0.3`; logs de retenção fracamente testados; `retry: false` nos jobs de retenção.
- **Consentimento e exclusão:** consentimento após exclusão sob `READ COMMITTED`; conceder já concedido responde 201 sem gravar; auditoria de consentimento sem `ip_hmac`; qualquer consumidor de `consent.revoked` bloqueia o novo grant; sem teste de interleaving concorrente revoke×grant; `DeletionDeadlineJob` duplica trabalho e alerta toda hora; `pending_contexts` fixado no pedido; `KeyError` de contexto sem apagador; `User.active` com `NOT IN`.
- **Perfil:** `display_name` sem trim; `to_unsafe_h` no PATCH; tamanho de motivações checado antes do `uniq`; `MAX_MOTIVATIONS` repetido no mobile.
- **Cobertura:** a cobertura de exportador só vê contextos com `models/`; exportação não varre por tabela; exportação antes da auditoria e fora de transação; `deletion_delivery_race_spec` pode travar a suíte se regredir (sem timeout) e usa `sleep 0.5`; nome do `domains_spec:214` promete mais que verifica.
- **Mobile:** `signOut` esconde falha do servidor e limpa o token mesmo sem resposta; sessão órfã se o SecureStore falha; sem bloqueio de `http://` fora de `__DEV__` e `allowBackup`; "Dar consentimento" a partir das configurações empilha telas; `formatDate` no fuso do aparelho; acessibilidade (rótulo duplicado, erro sem vínculo ao campo, foco nas confirmações, "Choice"); `onRetry` passa o evento; esportes salvos um a um sem aviso parcial; sem testes do `_layout` e de caminhos de erro das configurações.
- **Web:** foco cai no `body` ao fechar o painel; `close()` com `setTimeout 0`; alerta "why" depois de "Agora não"; aviso de revogação fraco para finalidades além de `health_data`; flash da página de privacidade antes do 401; sem confirmação após a exclusão; `messages.ts` duplicado entre os clientes; sem cadastro nem "esqueci a senha" na web; proxy só em desenvolvimento (produção exige o mesmo site).
- **Documentos:** `AC-02-08` cita FR-PROFILE-004; `USER_JOURNEYS.md:87` e `PRIVACY_AND_LGPD.md:22` com "anonimizado"; seção "Evidência" fora do `TEMPLATE.md`; texto do `AC-02-05` ("arquivo privado e de vida curta") diferente do desenho sem arquivo (R23); `CLAUDE.md` "sem commit sem autorização" mantido como está, porque os commits seguiram o plano aprovado.

**Incidente.** Um subagente rodou `db:drop` sem `DATABASE_URL` e apagou o banco local `app_development`. Foi recriado a partir de `schema.rb`; os dados locais se perderam (só desenvolvimento, sem dado real). `device_label` antigo em claro não decifra. Proteção adicionada: os comandos `db:drop`, `db:reset` e `db:purge` passaram a pedir confirmação (`ask`) nos dois `settings.local.json`.

## 7. Decisões tomadas durante a execução

Tomadas em seu nome. Cada uma mostra o custo se estiver errada. O número R37 não foi usado; nenhuma decisão ficou de fora.

1. **R1:** a Tarefa 0 não repete a transição de STATUS, já feita em `c91b7c7`. Custo: nenhum.
2. **R2:** `APP_WEB_URL` é a quinta variável obrigatória em produção. Custo: uma variável a mais.
3. **R3:** `outbox_events` usa `user_id` e entra no registro de dados pelo `shared`. O exportador devolve vazio e o apagador remove os eventos, menos `user.deletion_requested`. Custo: evento pendente de outro tipo apagado na exclusão.
4. **R4:** `Shared::Outbox.discard_if` é registrável, e Identity descarta com base em "exclusão pedida". Custo: evento atrasado recriaria dado (coberto por teste).
5. **R5:** `publish!` agenda o job após o commit, e o cron de 1 minuto fica de rede de segurança. Custo: um enqueue por evento.
6. **R6:** `POST /registrations` recebe `time_zone` obrigatório (IANA, validado com TZInfo). Custo: campo a mais no contrato de cadastro.
7. **R7:** refresh limitado só por IP; cadastro e entrada por IP e por e-mail normalizado. Custo: nenhum.
8. **R8:** pastas do mobile seguem o plano (`auth`, `onboarding`, `settings`), não as do documento da fase. Custo: renomear pastas.
9. **R9:** fuso no mobile por `Intl`, sem pacote novo. Custo: Hermes sem `Intl` completo daria fuso errado, e o cadastro mostraria erro.
10. **R10:** tentar a demonstração no emulador. Foi feita. Custo evitado.
11. **R11:** a Tarefa 13 para antes de push e PR. Custo: nenhum.
12. **R12:** `DOMAIN_MODEL.md:9` corrigido já na Tarefa 0. Custo: nenhum.
13. **R13:** o novo implementador da Tarefa 2 confere o trabalho sem registro, prova os testes por mutação e completa. Custo: defeito oculto, mitigado pela revisão.
14. **R14:** `attempts` por evento, não por consumidor. Custo: consumidor que falha tarde tem menos de 8 tentativas próprias.
15. **R15:** o `PayloadCheck` aceita fuso IANA validado por TZInfo. Custo: uma regra a mais no filtro.
16. **R16:** o eraser de Identity segue o design 4.4: só `sessions` na Tarefa 3, `users` na Tarefa 8. Custo: nenhum.
17. **R17:** token no caminho do `PATCH /password_resets/:token`, com filtro nos logs da app. Custo: mudar rota e contrato, e o log de proxy vira pendência da Fase 09.
18. **R18:** senha fraca no reset responde 422 `validation_failed`. Custo: um código de erro a mais.
19. **R19:** antes de o perfil existir, as rotas de perfil e esportes respondem 409 `profile_pending`. Custo: um código de erro a mais.
20. **R20:** o spec de `health_data` lista todas as rotas autenticadas e as liberadas sem ele. Custo: teste a manter.
21. **R21:** `UserProfile::Api.time_zone` devolve `nil` com perfil pendente. Custo: checagem nas Fases 03 e 05.
22. **R22:** `notification_preferences` guardado e não exposto até a Fase 08. Custo: nenhum agora.
23. **R23:** exportação gerada na hora, sem arquivo, com limite por IP e auditoria `account_exported`. Custo: nenhum.
24. **R24:** a Tarefa 8 aplica o R4 (exclusão pedida, não só `deleted_at`). Custo: nenhum.
25. **R25:** `DELETE /account` isento de `health_data`, com limite por IP e auditoria de lista fechada. Custo: nenhum.
26. **R26:** spec de integração com o evento real de exclusão (AC-02-12). Custo: um spec a mais.
27. **R27:** senha errada em exportação e exclusão responde 401 `invalid_credentials`; o mobile só desconecta com 401 de sessão. Custo: deslogar a pessoa ao errar a senha.
28. **R28:** implementadores e revisores em sonnet; opus só na revisão final e nas rodadas 4 e 5. Custo: mais rodadas de correção.
29. **R29:** limpeza da outbox em job de `shared`; `consent_records` e `audit_events` por 5 anos provisórios. Custo: dois jobs diários.
30. **R30:** no `isolation_spec`, rota sem id prova isolamento por "B age e nada de A muda". Custo: tabela de casos maior.
31. **R31:** em conta ativa, `consent_records` guarda o último registro por finalidade além dos 5 anos. Custo: guardar um registro por finalidade além do prazo (vai ao jurídico).
32. **R32:** revogar `health_data` apaga esportes e limpa motivações e nome; fuso e unidades ficam. Custo: guardar fuso e unidades após a revogação.
33. **R33:** escritas de perfil reconferem o consentimento dentro da transação, com a linha travada. Custo: uma consulta à API de Identity por escrita.
34. **R34:** o consumidor sempre apaga; novo grant de `health_data` responde 409 `revocation_pending` enquanto houver revogação não entregue. Custo: novo consentimento espera até cerca de 1 minuto, e evento morto o bloqueia até o replay.
35. **R35:** a rodada 4 segue com o mesmo implementador sonnet, porque o achado era novo. Custo: mais uma rodada.
36. **R36:** `CleanupJob` nunca apaga evento morto, e o runbook entra agora. Custo: eventos mortos acumulam até alguém resolver.
37. **R38:** nota de 2026-11-13 retirada da ADR 0010, que a decisão cumpre sem alterar. Custo: nenhum.
38. **R39:** revisão de fechamento = `software-architect` (branch inteira), `security-reviewer` (delta) e `qa-reviewer`; backend e frontend contam pelas revisões completas anteriores. Custo: achado em código posterior a essas revisões.
39. **R40:** a corrida consumidor×apagador é corrigida agora, com lock `FOR SHARE` na regra de descarte. Custo: um lock por evento entregue.

## 8. Próximo passo

A fase não pode ser encerrada antes das decisões da seção 6(a). Para decidir, envie as mensagens que valem:

> Aprovo os textos de consentimento v1.

> Aceito as ADRs 0004, 0005 e 0018.

> Pode fazer o push e abrir o PR.

> Aprovo a Fase 02.

Depois da aprovação, a próxima linha do roadmap é a 03. Para começar:

> Vamos iniciar a fase 03.
