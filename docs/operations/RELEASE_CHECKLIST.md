# Checklists de liberação

Cada item precisa de evidência, conforme [DEFINITION_OF_DONE.md](../engineering/DEFINITION_OF_DONE.md). Item que não se aplica fica marcado como tal, com justificativa.

## M1 — Beta fechado

Antes de convidar as pessoas. Detalhes no [documento do marco](../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md).

### Conformidade

- [ ] Revisão por advogado concluída ([pendências](../security/PRIVACY_AND_LGPD.md)).
- [ ] Controlador definido e encarregado com contato público.
- [ ] Política de privacidade e termos publicados, com a lista de operadores.
- [ ] Telas de consentimento revisadas e versionadas.
- [ ] Termos do provedor de IA revisados, com a base de transferência internacional.
- [ ] Licenças de todas as bases nutricionais registradas na [ADR 0007](../architecture/decisions/0007-nutrition-data-sources.md).

### Produto

- [ ] Cadastro, maioridade, consentimentos e exclusão de conta funcionam em ambiente real.
- [ ] Foto, estimativa, confirmação, correção, histórico e registro manual funcionam.
- [ ] Metas diárias e check-in manual funcionam.
- [ ] Textos revisados contra a lista de [segurança de saúde](../security/HEALTH_DATA_SAFETY.md).
- [ ] Exibição de calorias, metas, textos e fontes de apoio revisados por profissional de saúde.

### Operação

- [ ] Deploy reproduzível, com reversão testada.
- [ ] Backup automático e **restauração testada**, com data, reaplicando a lista de exclusões.
- [ ] Monitoramento de erros ativo em API, jobs e app.
- [ ] Limite de análises por usuário e alerta de gasto configurados.
- [ ] Procedimento de incidente preparado.
- [ ] Armazenamento privado confirmado por tentativa de acesso sem assinatura.
- [ ] `RAILS_ENV=production` fixado na imagem. Sem ele, as rotas `/internal` existem e `RequiredEnv` não verifica nada.
- [ ] `config.hosts` definido pelo domínio de deploy, com exclusão de `/health/*`.
- [ ] TLS terminado no proxy, premissa de `assume_ssl` em `production.rb`, e sondas de saúde testadas.
- [ ] `SECRET_KEY_BASE`, `REDIS_URL` e `DATABASE_URL` validados em formato, com TLS onde o tráfego sair da rede privada.
- [ ] Retenção de logs definida, e também a de `error_message`, que o Sidekiq grava no Valkey ao falhar um job.
- [ ] `/health/ready` com limite de requisições ou resultado em cache, e resposta pública avaliada, por revelar qual dependência caiu.
- [ ] Captura de crash nativo avaliada no mobile, com filtragem nativa.

### Beta

- [ ] Distribuição interna do app funcionando.
- [ ] Métricas de ativação e retenção, com consentimento.
- [ ] Canal para as pessoas darem retorno.
- [ ] Forma de encerrar o beta e tratar os dados definida.

## Lançamento

Antes de abrir ao público. Detalhes na [Fase 09](../roadmap/phases/PHASE_09_PRODUCTION.md).

### Qualidade

- [ ] Testes de todas as aplicações aprovados, incluindo end-to-end nos fluxos principais.
- [ ] Teste de carga com a meta de capacidade atendida.
- [ ] Acessibilidade verificada na web e no mobile.

### Segurança e privacidade

- [ ] Revisão de segurança completa, sem achados críticos ou importantes em aberto.
- [ ] Teste de isolamento entre usuários em todas as rotas.
- [ ] Revisão jurídica atualizada para a escala do lançamento.
- [ ] Revisão de textos e regras de segurança por profissional de saúde.

### Operação

- [ ] Recuperação de desastre ensaiada.
- [ ] Alertas com procedimento de ação.
- [ ] Documentação operacional atualizada.
- [ ] Custo mensal estimado para o volume esperado.

### Terceiros

- [ ] Aplicação no Strava revisada, com capacidade suficiente, ou Strava claramente limitado na oferta.
- [ ] Diretrizes de marca do Strava atendidas.
- [ ] Publicação nas lojas de aplicativos revisada, incluindo as regras para apps de saúde e pagamentos, verificadas na fonte.

### Produto

- [ ] Marca definida, sem o nome "Strava".
- [ ] Monetização decidida ([ADR 0012](../architecture/decisions/0012-monetization-options.md)), ou lançamento gratuito decidido, com orçamento.

## Encerramento da aplicação no Strava

Se a integração for encerrada:

1. Desligar importação e webhook, e remover a assinatura.
2. Revogar os tokens de todos os atletas.
3. **Apagar todos os dados do Strava,** incluindo o que a [ADR 0017](../architecture/decisions/0017-derived-data-after-source-removal.md) definir como derivado.
4. **Backups:** o termo lido não traz exceção para backups. Confirme o tratamento com o Strava, ou aguarde a rotação, antes de certificar.
5. **Certificar por escrito,** como exige a seção 4.4 do termo de API.
6. Avisar os usuários.
7. Registrar a data e a evidência.

## Incidentes

Procedimento em [SECURITY.md](../security/SECURITY.md). Acesso não autorizado a token do Strava exige aviso em até 24 horas.
