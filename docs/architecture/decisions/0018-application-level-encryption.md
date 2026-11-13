# 0018 — Cifragem em nível de aplicação

- **Data:** 2026-11-13
- **Requisitos relacionados:** NFR-SEC-001, NFR-SEC-003, NFR-PRIVACY-002

## Contexto

Banco, backups e armazenamento já são cifrados pela infraestrutura ([SECURITY.md](../../security/SECURITY.md)). Isso não protege contra leitura da tabela por quem tem acesso ao banco ou a uma cópia. A Fase 02 precisa decidir quais colunas ganham cifragem na aplicação. A ferramenta é a criptografia do Active Record, cujas chaves e opções estão no [registro de fontes](../EXTERNAL_SOURCES.md).

## Problema

Quais colunas dos dados de identidade e de perfil são cifradas pela aplicação, de que forma, e com que chaves?

## Alternativas

1. **Só cifragem de infraestrutura:** nenhum código, mas um dump do banco expõe e-mails e nomes.
2. **Active Record Encryption nas colunas pessoais livres:** pouco código, nativo do Rails, com custo de perder busca e índice nas colunas não determinísticas.
3. **Cifrar todas as colunas:** máxima proteção, mas quebra consultas, índices e constraints sobre listas fechadas e identificadores, sem ganho proporcional.
4. **Cifragem por envelope em biblioteca própria ou externa:** mais flexível, mais código de segurança para uma pessoa só manter.

## Decisão

Alternativa 2.

| Coluna | Cifragem | Motivo |
|---|---|---|
| `users.email` | determinística | A entrada, o cadastro e a recuperação buscam por e-mail, e o índice único precisa de igualdade. |
| `user_profiles.display_name` | não determinística | Texto livre, nunca consultado. |
| `sessions.device_label` | não determinística | Texto livre vindo do aparelho, nunca consultado. |

**Deliberadamente não cifrados:** listas fechadas (finalidade e versão de consentimento, esporte, nível, ação de auditoria, nome de evento), identificadores (UUIDs, `user_id`), fuso horário e unidades, datas, e digests (`sessions.token_digest`, `ip_hmac`). Cifrá-los quebraria constraints e índices, e não protege nada: não são texto livre pessoal, e digests já são irreversíveis.

**Chaves**, por variável de ambiente: `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` e `AUDIT_IP_HMAC_KEY` (HMAC do IP em `audit_events`). Em produção as quatro são obrigatórias e têm no mínimo 32 caracteres, verificado na inicialização (`RequiredEnv`); desenvolvimento e teste usam valores públicos locais. Nenhuma chave no repositório.

**Item em aberto: rotação de chaves.** Não há procedimento definido nem testado. Trocar uma chave hoje deixaria dados ilegíveis. Antes do M1 é preciso decidir e testar a rotação (a criptografia do Active Record aceita chaves anteriores, mas isso não foi exercitado) e documentá-la em [SECURITY.md](../../security/SECURITY.md).

## Justificativa

Protege os únicos textos pessoais livres e o identificador de contato, com o menor código de segurança próprio. O e-mail determinístico é o custo aceito para poder buscar por ele: dois e-mails iguais geram o mesmo texto cifrado dentro da mesma chave.

## Consequências

- Não se busca nem ordena por `display_name` ou `device_label`.
- Perder ou trocar chave sem procedimento torna as colunas ilegíveis; rotação segue pendente.
- Coluna nova com texto pessoal livre precisa decidir a cifragem no mesmo PR.
- `raw_response` e dados de fases futuras serão decididos nas respectivas fases, por classe de dado.

## Evidência

- `apps/api/spec/domains/identity/user_spec.rb`, `session_device_label_spec.rb` e `apps/api/spec/domains/user_profile/profile_spec.rb`: o valor gravado no banco é cifrado, e a busca por e-mail funciona.
- `apps/api/spec/lib/required_env_spec.rb`, `spec/boot/production_boot_spec.rb` e `spec/lib/cache_and_keys_spec.rb`: variáveis e tamanho mínimo exigidos no boot de produção.
- Suíte completa em 2026-11-13: `583 examples, 0 failures`.

## Estado da decisão

Aceita
