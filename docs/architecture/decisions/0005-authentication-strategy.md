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
**Mobile:** token em armazenamento seguro do sistema (`expo-secure-store`, a confirmar).

## Decisão

**Já vale:** sessões revogáveis por dispositivo; senha com hash forte; limite de tentativas; nenhum token em armazenamento inseguro; `sessions` guarda só o digest do token.

**Fica para a Fase 02:** a biblioteca e o formato do token. Critério: menos código próprio de segurança, revogação por dispositivo e compatibilidade com as versões da ADR 0002. Consultar a documentação oficial antes de decidir.

**Proposta a validar:** alternativa 1, com tokens opacos.

## Justificativa

A necessidade de revogação por dispositivo, somada à simplicidade, favorece tokens opacos. A confirmação depende da leitura da documentação atual.

## Consequências

- Mobile e web podem usar formas diferentes de transporte com o mesmo modelo de sessão.
- A verificação de token consulta o banco, com impacto aceitável na escala atual.

## Estado da decisão

Proposta
