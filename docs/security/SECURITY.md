# Segurança

Modelo de ameaças e controles do produto. Os controles de identidade, sessão e cifragem da Fase 02 estão implementados e testados; a coluna "Fase" indica onde cada controle é implementado e testado.

## O que mais precisa de proteção

1. Fotos de refeições e dados de saúde.
2. Tokens do Strava e chaves de provedores.
3. Contas de usuários.
4. O custo de IA, que um ataque pode fazer disparar.

## Modelo de ameaças

| Superfície | Ameaça | Controle | Fase |
|---|---|---|---|
| Upload de foto | Arquivo malicioso, tamanho excessivo, uso de URL de terceiros | URL assinada restrita a tipo e tamanho e com prazo máximo de 15 minutos; validação do objeto real após o envio; reprocessamento e remoção de EXIF antes da IA | 03 |
| Acesso a fotos | URL vazada, leitura por outra pessoa | Bucket privado; URLs assinadas curtas; nunca em logs; escopo por dono | 03 |
| Imagem enviada à IA | Instrução maliciosa escrita na foto | Tratar a imagem como dado; validar saída por schema; sem ferramentas nem dados de terceiros no prompt | 03 |
| API | Acesso a dados de outra pessoa (IDOR) | Consultas a partir do usuário autenticado; teste automático por recurso | 02 |
| Autenticação | Força bruta, sessão roubada | Limite de tentativas (por IP; por e-mail só nas entradas com senha errada, reservado antes da conferência da senha; por conta na reautenticação); hash forte; token por dispositivo com digest no banco e revogação. Limite conhecido: cinco senhas erradas para um e-mail bloqueiam a entrada dessa pessoa por 15 minutos, de qualquer IP | 02 |
| Clientes | Token roubado do aparelho ou navegador | Armazenamento seguro no mobile; cookie `HttpOnly` e `SameSite` na web | 02 |
| Webhook do Strava | Evento forjado, excesso de requisições | Conferir `subscription_id`; nunca confiar no conteúdo, sempre buscar na API; limite de requisições | 04 |
| OAuth do Strava | CSRF, código interceptado | `state` assinado de uso único; troca imediata; segredo só no backend | 04 |
| Tokens de integração | Vazamento do banco | Cifragem em nível de aplicação com chave fora do banco | 04 |
| Custo de IA | Abuso, conta falsa em massa | Limite por usuário; alerta de gasto total; limite de contas por origem | 03 |
| Dependências | Pacote vulnerável ou malicioso | Auditoria no CI; versões travadas; justificativa para dependência nova | 01 |
| CI e segredos | Segredo no repositório | Varredura no CI; `.gitignore`; regras `deny` do Claude Code | 01 |
| Agentes de IA de desenvolvimento | Leitura de segredo, comando destrutivo | Regras `deny` em `.claude/settings.json`; revisores sem ferramenta de edição; limite descrito abaixo | 00 |
| Administração e operação | Acesso indevido por console, banco ou painel de filas | Sem painel administrativo com conteúdo de saúde; operações com auditoria e acesso restrito | 02, M1 |
| Exportação e exclusão | Sessão roubada leva o histórico ou apaga a conta | Reautenticação recente; arquivo de exportação privado e de vida curta | 02 |
| Filas | Redis com argumentos de jobs e conjunto de mortos | Jobs só com identificadores; sem dados de saúde em argumentos | 01 |
| Foto no aparelho | Imagem fica após sair ou excluir a conta | App apaga cópias locais ao concluir o envio, ao sair e ao excluir | 03 |
| Processamento de imagem | Bomba de descompressão | Limite de dimensões e tamanho antes de decodificar | 03 |
| Restauração de backup | Cópia real em ambiente sem controle; contas excluídas ressuscitadas | Ambiente com os mesmos controles, descartado ao final; lista de exclusões reaplicada | M1 |
| Notificações | Dado de saúde na tela de bloqueio | Textos genéricos; token do aparelho revogado ao encerrar a sessão | 08 |

## Cifragem

- **Em trânsito:** TLS em toda comunicação externa.
- **Em repouso:** banco, backups e armazenamento cifrados pela infraestrutura.
- **Em nível de aplicação:** tokens de integração e de aparelho (fases futuras) e, desde a Fase 02, `users.email` (determinística), `user_profiles.display_name` e `sessions.device_label`, pela criptografia do Active Record ([ADR 0018](../architecture/decisions/0018-application-level-encryption.md)). `raw_response` e outras colunas de fases futuras serão decididas por classe de dado.
- **Chaves:** fora do repositório e do banco; em produção, `ACTIVE_RECORD_ENCRYPTION_*` e `AUDIT_IP_HMAC_KEY` com no mínimo 32 caracteres, verificado no boot. **A rotação ainda não tem procedimento:** o registro de fontes diz que a rotação não é suportada para a cifragem determinística (`users.email`), então girar essa chave exigirá um procedimento de recifragem, a desenhar e testar antes do M1 (pendência da [ADR 0018](../architecture/decisions/0018-application-level-encryption.md)).

## Segredos

- Nunca no repositório, em logs, em mensagens de erro nem em código dos clientes.
- `.env` é ignorado pelo Git. Variáveis estão listadas em [ENVIRONMENT_VARIABLES.md](../operations/ENVIRONMENT_VARIABLES.md), sem valores.
- Segredos de produção ficam no gerenciador da plataforma.
- O `client_secret` do Strava e as chaves de IA existem somente no backend.

### Limite conhecido das regras do Claude Code

As regras `deny` de `Read` bloqueiam as ferramentas de arquivo, mas a documentação não declara que isso cobre `cat .env` via Bash. Os revisores têm `Bash` para rodar testes, e `tools` não restringe comandos individuais: a instrução deles proíbe alterar arquivos, mas **isso é instrução, não controle técnico**. As regras reduzem o risco e não são uma garantia. A proteção principal é não ter segredos reais na máquina de desenvolvimento além do necessário. A regra `Read(**/.env.*)` também bloqueia `.env.example`, então, para mudar esse arquivo, o Claude pede ao responsável.

## Sessão, transporte e limites

- **Token opaco:** o banco guarda só o digest. Sessão ociosa expira em 30 dias e a absoluta em 90 ([ADR 0005](../architecture/decisions/0005-authentication-strategy.md)).
- **Web:** cookie `__Host-session`, assinado, `HttpOnly`, `Secure`, `SameSite=Lax`, `Path=/`. Nenhum token em `localStorage`. **Mobile:** `Authorization: Bearer`, com o token no SecureStore do sistema.
- **Origin:** a API não usa a proteção CSRF de formulário do Rails. Requisição que muda estado e usa ou pede o cookie só passa com `Origin` em `ALLOWED_ORIGINS`; senão, `403`. Requisição só com Bearer não depende de Origin.
- **Respostas** sempre com `Cache-Control: no-store`.
- **Limites** (`429` com `Retry-After`; chaves em HMAC no cache, sem IP nem e-mail em claro):

| Rota | Limite |
|---|---|
| Cadastro | 10 por IP em 3 min; 5 por e-mail em 15 min |
| Entrada | 10 por IP em 3 min; 5 **falhas** por e-mail em 15 min |
| Renovação | 10 por IP em 3 min |
| Recuperação de senha | 10 por IP em 3 min; 20 por e-mail em 1 h |
| Exportação e exclusão | 10 por IP em 3 min; 5 por conta em 15 min |

- **Trade-offs conhecidos:** (1) o limite de falhas por e-mail deixa um terceiro bloquear por 15 minutos a entrada de uma pessoa, de qualquer IP; a vaga é reservada de forma atômica antes de conferir a senha, para que requisições paralelas não ganhem tentativas, e é devolvida quando a senha está certa. (2) O limite por conta em exportação e exclusão impede que um token roubado teste senhas trocando de IP, ao custo de travar a própria pessoa por 15 minutos após cinco requisições, com contadores separados para exportação e exclusão (toda requisição conta, certa ou errada). (3) A recuperação sempre responde `202`, então toda requisição conta e o teto é alto. (4) O token de recuperação vai no caminho da rota: os logs da aplicação filtram o caminho, mas log de proxy à frente da API é pendência da Fase 09.
- **Eventos mortos da outbox** têm procedimento em [RUNBOOK_OUTBOX.md](../operations/RUNBOOK_OUTBOX.md).

## Autorização

- Por padrão, tudo é negado.
- Consultas de dados de usuário sempre partem do usuário autenticado.
- Cada recurso tem um teste que confirma a resposta `404` para outra pessoa.
- Não há perfil administrativo com acesso a conteúdo de saúde. Se um dia for necessário, exigirá uma ADR.

## Auditoria

`audit_events` registra login, falhas repetidas, concessão e revogação de consentimento, exportação, exclusão, conexão e desconexão de integração. Não contém conteúdo de saúde. Retenção em [DATABASE_DESIGN.md](../architecture/DATABASE_DESIGN.md).

## Ferramentas

| Ferramenta | Uso | Fase |
|---|---|---|
| Brakeman | Análise estática do Rails, no CI. A [licença](../architecture/EXTERNAL_SOURCES.md) trata uso comercial à parte e cita analisar o próprio software como não comercial: enquadramento pendente na revisão jurídica | 01 |
| `bundler-audit` | Dependências Ruby, no CI | 01 |
| `npm audit --audit-level=high` | Dependências JavaScript, no CI | 01 |
| Gitleaks 8.30.1 | Varredura de segredos no histórico, no CI. Só recebe correção de segurança: reavaliar no M1 | 01 |
| `security-reviewer` | Revisão a cada fase com superfície nova | Todas |

As ferramentas são confirmadas na Fase 01. Achado alto reprova o CI, e uma exceção exige justificativa registrada.

## Resposta a incidentes

1. **Conter:** revogar credenciais, tirar do ar o que for necessário.
2. **Avaliar:** dados e pessoas afetadas, por registros de auditoria e logs.
3. **Comunicar:**
   - **LGPD, art. 48:** à autoridade e aos titulares, quando houver risco ou dano relevante, em prazo razoável conforme a ANPD. O prazo vigente é confirmado na revisão jurídica.
   - **Strava:** em até **24 horas** da descoberta de acesso não autorizado a token, como exige o termo de API.
4. **Corrigir:** causa raiz, com teste de regressão.
5. **Registrar:** relatório do incidente. Quem responde é o responsável pelo produto. A indicação do encarregado é uma pendência anterior ao M1.

O procedimento detalhado é preparado para o [M1](../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md).

## Vulnerabilidades de dependências

Crítica ou alta em ferramenta de auditoria, com exposição real: corrigir antes de seguir. Em achados dos revisores do projeto, crítico e importante bloqueiam o encerramento, salvo exceção registrada pelo responsável. Sem exposição: registrar a justificativa e o prazo. Revisão a cada encerramento de fase.
