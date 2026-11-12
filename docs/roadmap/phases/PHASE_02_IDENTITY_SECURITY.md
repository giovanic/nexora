# Fase 02 — Identity, Security & Privacy

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** FR-ID-001, FR-ID-002, FR-ID-003, FR-ID-004, FR-ID-005, FR-ID-006, FR-ID-007, FR-ID-008, FR-PROFILE-001, FR-PROFILE-002, FR-PROFILE-003, NFR-SEC-001, NFR-SEC-003, NFR-SEC-006, NFR-PRIVACY-002, NFR-PRIVACY-003
- **ADRs:** [0005](../../architecture/decisions/0005-authentication-strategy.md), [0010](../../architecture/decisions/0010-adults-only-mvp-and-consent.md)

## Objetivo

Cada pessoa acessa sua conta e somente seus dados, com consentimento por finalidade, exportação e exclusão funcionando e testados, antes de existir qualquer dado de saúde no sistema.

## Escopo

**Inclui:** contextos Identity & Access e User Profile; cadastro; entrada; sessões; recuperação de senha; perfil, preferências e perfil esportivo; consentimentos; exportação; exclusão; retenção; cifragem; telas correspondentes no mobile, e na web apenas o necessário para os fluxos.

**Não inclui:** dados de refeições, Strava, login social, autenticação de dois fatores ou painel web completo.

## Funcionalidades

- **Cadastro** com e-mail e senha, exigindo a confirmação de 18 anos ou mais. `adult_confirmed_at` é obrigatório no banco.
- **Sessões** por dispositivo, com digest no banco, expiração, renovação e revogação. Biblioteca e formato decididos na ADR 0005.
- **Armazenamento nos clientes:** seguro no mobile, cookie `HttpOnly` e `SameSite` na web.
- **Recuperação de senha** por link de uso único, com prazo, sem revelar se o e-mail existe.
- **Limite de tentativas** em cadastro, entrada e recuperação.
- **Perfil:** nome de exibição, fuso, unidades, preferências.
- **Perfil esportivo:** um ou mais esportes, com nível de `beginner`, `intermediate` ou `advanced`. Mudanças valem daí em diante.
- **Consentimentos** por finalidade (`health_data`, `food_photo_ai`, `strava_integration`, `usage_metrics`), com versão do texto, histórico e revogação tão fácil quanto a concessão.
- **Exportação** em formato estruturado: cada contexto fornece seu pacote por uma interface comum.
- **Exclusão:** evento `user.deletion_requested`, com acompanhamento até a conclusão por todos os contextos.
- **Retenção:** rotina automática, com prazos de [DATABASE_DESIGN.md](../../architecture/DATABASE_DESIGN.md), que pode ser estendida pelas fases seguintes.
- **Auditoria:** `audit_events` nas ações sensíveis.
- **Outbox:** esta fase é a dona da implementação, com `outbox_events`, `consumed_events`, publicador, conferência por consumidor e registro compartilhado de exportadores e apagadores ([ADR 0004](../../architecture/decisions/0004-domain-events-transactional-outbox.md)).
- **Cifragem:** decidir em ADR quais colunas, por classe de dado, são cifradas em nível de aplicação.

## Dependências

- **Fase 01** concluída: API, clientes, CI e observabilidade comprovados.
- **Fontes a consultar:** documentação do Rails para autenticação e cifragem, documentação do Expo para armazenamento seguro.

## Arquivos e módulos esperados

```text
apps/api/app/domains/identity/
apps/api/app/domains/user_profile/
apps/api/app/domains/shared/            Outbox e registro de exportadores e apagadores
apps/api/db/migrate/                     users, sessions, consent_records, audit_events, account_deletions, user_profiles, sport_profiles, outbox_events, consumed_events
apps/mobile/src/features/auth/
apps/mobile/src/features/privacy/
apps/mobile/src/features/profile/
apps/web/src/features/auth/
packages/contracts/                      Rotas desta fase
```

## Critérios de aceite

- `AC-02-01` (FR-ID-001): sem confirmar maioridade, a conta não é criada, tanto pela API quanto pelo banco. **Comprovado por:** teste de requisição e teste de constraint.
- `AC-02-02` (FR-ID-002): entrar, sair, renovar e revogar por dispositivo funcionam, e uma sessão revogada ou expirada recebe `401`. **Comprovado por:** testes de requisição e fluxo no app.
- `AC-02-03` (FR-ID-003): link de recuperação é de uso único, expira e não revela a existência do e-mail. **Comprovado por:** testes de requisição.
- `AC-02-04` (FR-ID-004): excluir a conta exige reautenticação, é acompanhada até a conclusão por contexto, e remove ou anonimiza os dados de todas as tabelas. **Comprovado por:** teste que semeia cada tabela, inclusive campos JSON, com um marcador, detecta tabela nova sem tratamento e prova que evento atrasado não recria dados.
- `AC-02-05` (FR-ID-005): a exportação exige reautenticação, entrega todos os dados da pessoa e nenhum dado de outra, e o arquivo é privado e de vida curta. **Comprovado por:** teste com duas contas, e verificação que detecta contexto novo sem exportador.
- `AC-02-06` (FR-ID-006): em todo recurso, outra pessoa recebe `404`, e nada é alterado. **Comprovado por:** teste por rota e verificação que detecta rota nova sem cobertura.
- `AC-02-07` (FR-ID-007, FR-ID-008): conceder e revogar geram registros com versão e data, e a tabela de efeitos de revogação em [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md) está implementada para o que já existe. **Comprovado por:** testes e demonstração no app. Cada fase seguinte testa a interrupção dos tratamentos que cria.
- `AC-02-08` (FR-PROFILE-001, FR-PROFILE-002, FR-PROFILE-003): perfil e perfil esportivo funcionam, e mudar o nível não reescreve histórico. **Comprovado por:** testes.
- `AC-02-09` (NFR-SEC-001, NFR-SEC-003, NFR-SEC-006): as colunas definidas em ADR estão cifradas, o limite de tentativas responde `429`, e ações sensíveis ficam em auditoria com lista fechada de campos. **Comprovado por:** testes, incluindo uma falha de login que não grava o e-mail digitado.
- `AC-02-10` (NFR-PRIVACY-002, NFR-PRIVACY-003): cada direito do art. 18 tem fluxo implementado ou documentado, e a rotina de retenção apaga dados vencidos. **Comprovado por:** tabela de [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md) atualizada e teste da rotina.
- `AC-02-11`: ADR 0005 e a ADR de cifragem decididas, com evidência. **Comprovado por:** leitura das ADRs.
- `AC-02-12`: a outbox entrega `user.deletion_requested` mesmo com falha do consumidor, reprocessa sem efeito duplicado, e a conferência acusa consumidor faltante. **Comprovado por:** teste de integração com falha injetada.
- `AC-02-13`: logs de cadastro, entrada, recuperação, exportação e exclusão, incluindo caminhos de falha, não contêm senhas, tokens ou e-mails. **Comprovado por:** teste sobre os logs.

## Testes

- Isolamento entre usuários por rota.
- Sessões, incluindo renovação concorrente.
- Consentimento: estado atual a partir do histórico.
- Exclusão: varredura do esquema.
- Telas: carregando, vazio, erro, teclado e leitor de tela nos fluxos de entrada e privacidade.
- Logs de um fluxo completo sem senhas, tokens ou e-mails.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Autenticação caseira com falha | Invasão de contas | Menos código próprio, biblioteca avaliada, revisão de segurança |
| Exclusão esquece tabela futura | Violação da LGPD | Teste que detecta tabela nova |
| Texto de consentimento genérico | Consentimento nulo | Telas por finalidade, revisão jurídica no M1 |
| Maioridade declaratória | Menor usando o app | Limitação registrada; revisão jurídica |

## Entregáveis

Contextos Identity & Access e User Profile, telas, contrato atualizado, documentos de privacidade atualizados, ADR 0005 e relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais: `security-reviewer` sem achado crítico ou importante em aberto.

## Estratégia de revisão

`security-reviewer` (principal), `software-architect` (limites, outbox), `backend-reviewer`, `frontend-mobile-reviewer`, `qa-reviewer` (isolamento e exclusão). O responsável aprova os textos de consentimento e o relatório.
