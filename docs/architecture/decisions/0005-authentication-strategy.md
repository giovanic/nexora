# 0005 — Estratégia de autenticação

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-ID-001, FR-ID-002, FR-ID-003, NFR-SEC-003

## Contexto

A API atende um app móvel e um painel web. O produto lida com dados sensíveis, e é mantido por uma pessoa, então a solução precisa ter pouco código próprio de segurança. As capacidades atuais das bibliotecas não foram verificadas nesta fase.

## Problema

Como autenticar mobile e web com sessões revogáveis por dispositivo, sem manter uma implementação caseira de criptografia?

## Alternativas

1. **Gerador de autenticação do Rails e tokens opacos em banco:** pouca dependência, revogação simples.
2. **Devise com tokens:** muito conhecida, mas pensada para sessões de navegador e com mais peso em uma API.
3. **Rodauth:** recursos fortes de segurança, curva de aprendizado maior.
4. **JWT sem estado:** dispensa consulta ao banco, mas a revogação por dispositivo fica mais difícil e reintroduz estado.
5. **Provedor externo de identidade:** tira o problema de casa, mas adiciona custo, dependência e transferência de dados pessoais.

**Web:** cookie `HttpOnly` e `SameSite` em vez de token em `localStorage`.
**Mobile:** token em armazenamento seguro do sistema (`expo-secure-store`).

## Decisão

Alternativa 1, com tokens opacos, como foi construída na Fase 02 (spec: `docs/superpowers/specs/2026-11-11-identity-security-design.md`).

- **Token:** opaco, de gerador criptográfico. O banco guarda só o digest (`sessions`); o token em claro existe apenas na resposta e no cliente.
- **Senha:** `has_secure_password` (bcrypt), com tamanho máximo de 72 bytes validado. Tokens de recuperação de senha são de uso único e expiram (`generates_token_for`); trocar a senha encerra todas as sessões.
- **Web:** cookie assinado `__Host-session`, `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`, sem token no corpo da resposta. Como a API não usa a proteção CSRF de formulário do Rails, toda requisição que muda estado e usa ou pede o cookie exige `Origin` da lista `ALLOWED_ORIGINS`; sem ela, `403`. Em desenvolvimento, o Vite encaminha `/api` para a API, mantendo tudo no mesmo site.
- **Mobile:** `Authorization: Bearer`, com o token guardado no `expo-secure-store` (Keychain no iOS, Keystore no Android).
- **Cliente:** o campo `client` (`web` ou `mobile`) no cadastro e na entrada escolhe o transporte.
- **Vida da sessão:** ociosa de 30 dias, absoluta de 90. A renovação (`POST /sessions/refresh`) troca o token, com a linha da sessão travada: duas renovações simultâneas com o mesmo token, só uma vence e a outra recebe `401`. Sessão revogada ou expirada recebe `401`.
- **Respostas:** todas com `Cache-Control: no-store`.
- **Limites de tentativas** (contador no cache, com chaves em HMAC, sem IP nem e-mail em claro; excedido responde `429` com `Retry-After`):
  - cadastro, entrada, recuperação e renovação: 10 por IP em 3 minutos; cadastro: também 5 por e-mail normalizado em 15 minutos; recuperação: 20 por e-mail em 1 hora;
  - **entrada, por e-mail normalizado: só falhas contam.** A vaga é reservada de forma atômica antes de conferir a senha e devolvida quando a senha está certa, de modo que requisições paralelas não ganham tentativas extras;
  - **exportação e exclusão de conta:** por IP e também **por conta** (5 em 15 minutos), porque um token de sessão roubado não pode permitir tentativas ilimitadas de senha trocando de IP.
- **Trade-off conhecido:** cinco senhas erradas para um e-mail recusam a entrada dessa pessoa por 15 minutos, de qualquer IP. Os outros freios são o limite por IP e o custo do bcrypt. Ver [SECURITY.md](../../security/SECURITY.md).

Fatos externos (gerador de autenticação do Rails, `has_secure_password`, `rate_limit`, Expo SecureStore, OWASP sobre sessões, `bcrypt`) estão no [registro de fontes](../EXTERNAL_SOURCES.md), verificados na Fase 02. Esta ADR não acrescenta fato externo novo.

## Justificativa

A revogação por dispositivo e a simplicidade favorecem tokens opacos com consulta ao banco. O digest no banco limita o dano de um vazamento da tabela. O cookie `__Host-` não aceita domínio e exige `Secure` e `Path=/`, e a checagem de `Origin` cobre o CSRF sem depender de token de formulário.

## Consequências

- Mobile e web usam transportes diferentes com o mesmo modelo de sessão.
- A verificação consulta o banco a cada requisição, com impacto aceitável na escala atual.
- O limite de falhas por e-mail permite que terceiros atrasem a entrada de uma pessoa (trade-off acima).
- Os limites usam o cache da aplicação, que precisa ser compartilhado entre processos em produção (Valkey).
- Log de proxy à frente da API pode registrar o token de recuperação, que vai no caminho de `PATCH /password_resets/:token`; pendência da Fase 09.

## Evidência

Suíte completa da API em 2026-11-13, no commit 35684a2: `bundle exec rspec` com `583 examples, 0 failures`, saída 0. Specs principais, em `apps/api/spec`:

- `requests/sessions_spec.rb`, `requests/registrations_spec.rb`, `requests/password_resets_spec.rb`: entrada, saída, renovação (inclusive simultânea), revogação, expiração, cookie, `Origin`, limites e `429`;
- `domains/identity/api_spec.rb`, `domains/identity/user_spec.rb`, `domains/identity/session_device_label_spec.rb`: regras do domínio, digest, e-mail normalizado;
- `requests/isolation_spec.rb`, `requests/no_store_spec.rb`, `requests/cors_spec.rb`, `integration/logging_spec.rb`: isolamento entre pessoas, `no-store`, origens e ausência de senha, token e e-mail nos logs.

O fluxo no app e no painel está nas capturas de tela versionadas em `docs/roadmap/reports/evidence/phase-02/` (`mobile-*.png` e `web-*.png`: cadastro, entrada, consentimento, sessões, saída, exportação com senha errada, token de recuperação inválido e exclusão).

## Estado da decisão

Aceita
