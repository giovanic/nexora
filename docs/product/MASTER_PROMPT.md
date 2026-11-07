> Texto original fornecido pelo responsável pelo produto na sessão de 2026-11-05, salvo sem alterações abaixo desta nota.
> Precedência: o [design aprovado](../superpowers/specs/2026-11-05-engineering-harness-design.md) prevalece apenas nos desvios que lista; fora deles, vale este texto.

# MASTER PROMPT — FITNESS COMPANION
## Construção do Engineering Harness, Arquitetura e Roadmap Completo

Atue como Principal Software Architect, Staff Engineer e Engineering Manager responsável por estruturar um produto SaaS de saúde, bem-estar e gamificação.

Você trabalhará dentro deste repositório utilizando Claude Code e o framework de desenvolvimento **Superpowers (obra/superpowers)**.

Sua primeira missão NÃO é desenvolver o aplicativo.

Sua primeira missão é construir um **Engineering Harness completo**, que servirá como sistema operacional de engenharia para todas as fases futuras do projeto.

O resultado deverá permitir que outro agente Claude Code, mesmo iniciando uma sessão completamente nova, consiga entender o produto, a arquitetura, as convenções, as fases, as regras de desenvolvimento e exatamente como executar cada etapa.

---

# 1. CONTEXTO DO PRODUTO

Nome de trabalho: Fitness Companion.

Não considere esse nome como marca definitiva.

## 1.1 Visão

Construir uma plataforma de acompanhamento de bem-estar e evolução pessoal que combine:

- Registro de alimentação por fotografias.
- Inteligência artificial multimodal para identificação de alimentos.
- Estimativas nutricionais.
- Integração oficial com Strava.
- Registro de atividades físicas.
- Objetivos e planejamento de hábitos.
- Sistema de gamificação com XP, níveis, conquistas e missões.
- Relatórios e análises de evolução.
- Experiência mobile e dashboard web.

O propósito é transformar a experiência de cuidar da saúde em uma jornada evolutiva e interativa.

O aplicativo deve ser visualmente interessante, intuitivo, inteligente e tecnicamente robusto.

## 1.2 Funcionalidades principais

### Food AI

O usuário fotografa uma refeição.

O sistema deverá:

1. Receber a fotografia.
2. Processar a imagem usando um modelo multimodal.
3. Identificar alimentos e preparações prováveis.
4. Estimar as porções.
5. Consultar uma base nutricional.
6. Calcular uma estimativa de composição nutricional.
7. Registrar o resultado no histórico.
8. Permitir correção da identificação ou das porções.

A experiência padrão deve exigir o mínimo de interação possível.

Entretanto, uma fotografia não permite medir com exatidão o peso, os ingredientes escondidos ou a preparação. Portanto, a plataforma deverá apresentar estimativas e incertezas, sem fingir precisão.

Avaliar a utilização da TBCA e de outras bases nutricionais, respeitando suas licenças e condições de uso.

### Strava Integration

Integração oficial com Strava API v3:

- OAuth 2.0.
- Sincronização de atividades.
- Webhooks.
- Histórico de atividades.
- Distância e duração.
- Tipo de atividade.
- Elevação e demais dados autorizados.
- Tratamento de duplicidade.
- Reconciliação de sincronização.
- Desconexão da conta.
- Exclusão dos dados associados.

Respeitar limites, escopos, termos e políticas oficiais do Strava.

Não construir scraping ou integrações não autorizadas.

### Goals Engine

Sistema de objetivos personalizados:

- Metas diárias.
- Metas semanais.
- Planejamento de atividades.
- Hábitos saudáveis.
- Recuperação.
- Consistência.
- Evolução pessoal.

### Gamification Engine

Motor independente de gamificação:

- XP.
- Níveis.
- Missões.
- Conquistas.
- Desafios.
- Sequências de consistência.
- Histórico de evolução.
- Recompensas virtuais.

A pontuação deve premiar hábitos sustentáveis, consistência e recuperação. Não deve premiar restrição alimentar, déficit calórico, excesso de exercício ou perda de peso.

### Web Dashboard

Painel completo com:

- Visão geral.
- Calendário.
- Histórico alimentar.
- Histórico de atividades.
- Evolução.
- Metas.
- Missões.
- Conquistas.
- Relatórios.
- Configurações.

### Mobile Application

Aplicativo para:

- Fotografar refeições.
- Consultar registros.
- Conectar o Strava.
- Consultar atividades.
- Acompanhar missões.
- Receber notificações.
- Consultar evolução.

---

# 2. SUA PRIMEIRA OBRIGAÇÃO: SUPERPOWERS

Antes de qualquer trabalho:

1. Verifique se o Superpowers está instalado e disponível no ambiente.
2. Identifique sua versão e as skills disponíveis.
3. Leia e utilize a skill `using-superpowers`.
4. Identifique as instruções atuais de cada skill antes de invocá-la.
5. Utilize obrigatoriamente o fluxo de trabalho recomendado pelo Superpowers.

Skills relevantes:

- `using-superpowers`
- `brainstorming`
- `writing-plans`
- `using-git-worktrees`
- `test-driven-development`
- `subagent-driven-development`
- `dispatching-parallel-agents`
- `requesting-code-review`
- `receiving-code-review`
- `systematic-debugging`
- `verification-before-completion`
- `finishing-a-development-branch`

Utilize os nomes e procedimentos efetivamente encontrados na instalação. Não invente skills nem simule sua execução.

**Regra fundamental:** Superpowers deve ser utilizado como metodologia obrigatória de desenvolvimento, e não apenas mencionado na documentação.

Não duplique suas skills originais dentro do repositório. Crie somente as instruções específicas necessárias para este produto.

Se o Superpowers estiver indisponível, informe objetivamente o bloqueio. Não declare que utilizou skills que não estavam disponíveis.

---

# 3. FASE ZERO — CONSTRUÇÃO DO ENGINEERING HARNESS

Essa é a única fase que você está autorizado a executar nesta sessão.

Você deverá construir uma estrutura de engenharia capaz de governar todo o desenvolvimento futuro.

Não implemente funcionalidades do produto nesta etapa.

## 3.1 Inspeção do projeto

Antes de criar arquivos:

- Inspecione a estrutura atual do repositório.
- Leia arquivos README existentes.
- Analise o Git status.
- Identifique a branch atual.
- Identifique tecnologias e dependências existentes.
- Identifique arquivos de configuração.
- Identifique versões de Ruby, Rails, Node e demais ferramentas, quando disponíveis.
- Identifique possíveis instruções existentes para Claude Code.
- Não sobrescreva configurações existentes sem entender sua finalidade.

Preserve alterações locais e arquivos não commitados.

Não execute comandos destrutivos.

Se o repositório estiver vazio, prepare a estrutura documental necessária.

## 3.2 Estrutura esperada do harness

Crie uma organização semelhante à seguinte, adaptando-a ao estado real do repositório:

```text
fitness-companion/
│
├── CLAUDE.md
├── README.md
│
├── .claude/
│   ├── settings.json
│   │
│   ├── rules/
│   │   ├── architecture.md
│   │   ├── backend.md
│   │   ├── frontend.md
│   │   ├── mobile.md
│   │   ├── testing.md
│   │   ├── security-and-privacy.md
│   │   └── product-safety.md
│   │
│   ├── agents/
│   │   ├── software-architect.md
│   │   ├── backend-reviewer.md
│   │   ├── frontend-mobile-reviewer.md
│   │   ├── security-reviewer.md
│   │   └── qa-reviewer.md
│   │
│   └── skills/
│       ├── phase-kickoff/
│       │   └── SKILL.md
│       │
│       └── phase-closeout/
│           └── SKILL.md
│
├── docs/
│   │
│   ├── product/
│   │   ├── PRODUCT_VISION.md
│   │   ├── PRD.md
│   │   ├── USER_JOURNEYS.md
│   │   └── FUNCTIONAL_REQUIREMENTS.md
│   │
│   ├── architecture/
│   │   ├── SYSTEM_OVERVIEW.md
│   │   ├── DOMAIN_MODEL.md
│   │   ├── DATABASE_DESIGN.md
│   │   ├── API_DESIGN.md
│   │   ├── AI_ARCHITECTURE.md
│   │   ├── STRAVA_INTEGRATION.md
│   │   ├── GAMIFICATION_ARCHITECTURE.md
│   │   └── decisions/
│   │
│   ├── security/
│   │   ├── SECURITY.md
│   │   ├── PRIVACY_AND_LGPD.md
│   │   └── HEALTH_DATA_SAFETY.md
│   │
│   ├── engineering/
│   │   ├── CODING_STANDARDS.md
│   │   ├── TESTING_STRATEGY.md
│   │   ├── CI_CD.md
│   │   ├── OBSERVABILITY.md
│   │   └── DEFINITION_OF_DONE.md
│   │
│   ├── roadmap/
│   │   ├── ROADMAP.md
│   │   ├── PHASE_EXECUTION_PROTOCOL.md
│   │   ├── PHASE_TEMPLATE.md
│   │   └── phases/
│   │       ├── PHASE_00_HARNESS.md
│   │       ├── PHASE_01_FOUNDATION.md
│   │       ├── PHASE_02_IDENTITY_SECURITY.md
│   │       ├── PHASE_03_FOOD_AI.md
│   │       ├── PHASE_04_STRAVA.md
│   │       ├── PHASE_05_GOALS.md
│   │       ├── PHASE_06_GAMIFICATION.md
│   │       ├── PHASE_07_APPLICATIONS.md
│   │       ├── PHASE_08_INTELLIGENCE.md
│   │       └── PHASE_09_PRODUCTION.md
│   │
│   └── operations/
│       ├── LOCAL_DEVELOPMENT.md
│       ├── ENVIRONMENT_VARIABLES.md
│       └── RELEASE_CHECKLIST.md
│
└── scripts/
    └── verify-harness.sh
```

Essa árvore é uma referência. Não crie documentos vazios apenas para preencher diretórios. Cada arquivo deverá possuir conteúdo real e útil.

---

# 4. ARQUITETURA TÉCNICA DO PRODUTO

Projete a arquitetura levando em consideração a possibilidade de evolução comercial e crescimento do número de usuários.

Minha preferência inicial é um monólito modular, com separação clara dos domínios.

Evite microsserviços prematuros.

## 4.1 Stack tecnológica de referência

| Camada | Tecnologia |
|---|---|
| Backend | Ruby on Rails API |
| Linguagem backend | Ruby |
| Banco | PostgreSQL |
| Cache e filas | Redis |
| Jobs | Sidekiq |
| Mobile | React Native + Expo |
| Linguagem mobile | TypeScript |
| Web | React + TypeScript |
| Web bundler | Vite |
| IA | Modelo multimodal com visão |
| Storage | S3 ou solução compatível |
| API | REST + OpenAPI |
| Containers | Docker |
| CI/CD | GitHub Actions |

Utilize essas tecnologias como baseline, não como justificativa para instalar tudo imediatamente.

Avalie versões estáveis e compatibilidade antes de registrar decisões definitivas.

## 4.2 Organização do monorepo

Avalie uma estrutura semelhante a:

```text
fitness-companion/
│
├── apps/
│   ├── api/
│   ├── web/
│   └── mobile/
│
├── packages/
│   └── contracts/
│
├── docs/
├── scripts/
├── docker/
│
├── .claude/
├── docker-compose.yml
└── README.md
```

Responsabilidades:

- `api`: backend Ruby on Rails.
- `web`: aplicação React.
- `mobile`: React Native Expo.
- `contracts`: contratos compartilhados de API e tipos gerados, se justificável.

Evite duplicar regras de negócio entre aplicações.

O backend será a fonte central da lógica de negócio.

## 4.3 Domínios do backend

Organize o backend em bounded contexts:

1. Identity & Access.
2. User Profile.
3. Nutrition.
4. Food AI.
5. Food Catalog.
6. Activities.
7. Strava Integration.
8. Goals.
9. Missions.
10. Gamification.
11. Notifications.
12. Progress & Analytics.

Documente:

- Responsabilidade de cada domínio.
- Modelos principais.
- Serviços.
- Eventos de domínio.
- Dependências permitidas.
- Dependências proibidas.
- Limites entre contextos.

Não crie Rails Engines para cada domínio sem justificativa arquitetural concreta.

## 4.4 Arquitetura orientada a eventos

Avalie eventos como:

```text
food_entry.created
food_analysis.completed
food_entry.confirmed

activity.imported
activity.updated
activity.deleted

goal.created
goal.progressed
goal.completed

mission.assigned
mission.completed

xp.awarded
level.unlocked
achievement.unlocked
```

A comunicação interna deve permitir que os domínios evoluam sem acoplamento excessivo.

Considere transactional outbox ou solução equivalente caso os requisitos de consistência justifiquem.

Inclua idempotência e proteção contra processamento duplicado.

---

# 5. REQUISITOS ARQUITETURAIS ESPECIAIS

## 5.1 Food AI Architecture

Documente uma arquitetura em pipeline:

```text
Mobile Camera
    |
    v
Backend Upload Authorization
    |
    v
Private Object Storage
    |
    v
Background Job
    |
    v
Multimodal AI Provider
    |
    v
Food Identification
    |
    v
Serving Size Estimation
    |
    v
Nutrition Database Adapter
    |
    v
Nutrition Calculator
    |
    v
Confidence / Uncertainty
    |
    v
Food Entry
```

Considere:

- Separação entre reconhecimento visual e cálculo nutricional.
- Abstração de provedores de IA.
- Versionamento de prompts.
- Respostas estruturadas com schema validado.
- Rastreamento de custos.
- Controle de falhas e retentativas.
- Dataset de avaliação.
- Histórico das análises.
- Correções feitas pelos usuários.
- Proveniência dos dados nutricionais.
- Faixas de estimativa e confiança.

Não armazene uma estimativa da IA como se fosse uma medição exata.

O sistema deve permitir trocar de provedor de IA sem reescrever o domínio Nutrition.

## 5.2 Strava Integration Architecture

Documente:

- Processo completo de OAuth.
- Escopos mínimos necessários.
- Armazenamento seguro de tokens.
- Renovação quando aplicável.
- Webhook subscription.
- Validação do mecanismo oficial de webhook.
- Processamento assíncrono.
- Sincronização inicial.
- Atualização de atividades.
- Exclusão de atividades.
- Idempotência.
- Rate limits.
- Reconciliação.
- Desconexão da integração.

Utilize exclusivamente a documentação oficial e verifique os requisitos atuais antes de tomar decisões definitivas.

Referência:

https://developers.strava.com/docs/

## 5.3 Database Architecture

Desenhe o modelo inicial e seus relacionamentos.

Considere pelo menos:

```text
users
user_profiles
consent_records

integrations
integration_tokens

food_entries
food_items
food_catalog
food_analysis_results

activities
activity_sync_events

goals
goal_check_ins

missions
user_missions

xp_transactions
user_levels

achievements
user_achievements

notifications
```

Documente:

- Responsabilidade de cada tabela.
- Chaves primárias.
- Chaves estrangeiras.
- Índices.
- Constraints.
- Unicidade.
- Soft delete quando necessário.
- Estratégia de auditoria.
- Estratégia de retenção de dados.

Não crie migrations nesta fase.

## 5.4 Gamification Architecture

O motor de gamificação deverá ser independente dos módulos de alimentação e atividades.

Documente:

- Como o XP é gerado.
- Como os níveis evoluem.
- Como as missões são criadas.
- Como a conclusão é validada.
- Como conquistas são desbloqueadas.
- Como impedir XP duplicado.
- Como funciona o histórico de recompensas.
- Como manter consistência entre eventos e pontuação.

Não utilize calorias consumidas, déficit calórico, calorias queimadas ou perda de peso como critérios de pontuação.

## 5.5 Privacy & Health Safety

Considere desde a fundação:

- LGPD.
- Dados pessoais e dados relacionados à saúde.
- Consentimento.
- Finalidade do tratamento.
- Retenção e exclusão.
- Controle de acesso.
- Criptografia.
- Proteção das fotografias.
- Segurança dos tokens.
- Auditoria.

O MVP deve priorizar usuários adultos.

Caso exista suporte a adolescentes, implemente um modo específico com proteção adequada: sem metas de restrição alimentar, déficit calórico, emagrecimento ou gamificação baseada no corpo e no gasto calórico.

Não transforme o produto em ferramenta de diagnóstico ou tratamento médico.

---

# 6. ROADMAP COMPLETO DO PRODUTO

Você deverá transformar as nove fases seguintes em documentos de engenharia completos.

Cada fase precisa ter:

- Objetivo.
- Escopo.
- Funcionalidades.
- Dependências.
- Arquivos e módulos esperados.
- Critérios de aceite.
- Testes.
- Riscos.
- Entregáveis.
- Definition of Done.
- Estratégia de revisão.

Não utilize descrições vagas como "implementar autenticação" ou "criar integração".

Detalhe o que precisa ser desenvolvido e como sua conclusão será comprovada.

## FASE 00 — ENGINEERING HARNESS

Escopo desta sessão.

- CLAUDE.md.
- Rules.
- Skills específicas do projeto.
- Subagents especializados.
- Arquitetura.
- Documentação.
- Roadmap.
- Protocolo de execução.
- Critérios de qualidade.
- Validação documental.

Critério de aceite: um novo Claude Code deve conseguir entender como desenvolver o projeto lendo o harness e os documentos indicados.

## FASE 01 — FOUNDATION & DEVELOPER EXPERIENCE

- Estrutura do monorepo.
- Rails API.
- React web.
- Expo mobile.
- PostgreSQL.
- Redis.
- Sidekiq.
- Docker.
- Configuração de ambiente.
- CI.
- Linters.
- Testes básicos.
- Health checks.
- Logs e observabilidade inicial.

Critério de aceite: todas as aplicações sobem localmente, os serviços se comunicam e o pipeline de CI executa verificações reais.

## FASE 02 — IDENTITY, SECURITY & PRIVACY

- Cadastro.
- Login.
- Autenticação.
- Sessões e tokens.
- Perfil.
- Preferências.
- Autorizações.
- Consentimentos.
- Proteção dos dados.
- Exclusão de conta.
- Política de retenção.
- Separação de dados entre usuários.

Critério de aceite: o usuário consegue acessar sua conta e somente seus próprios dados, com os fluxos de privacidade implementados e testados.

## FASE 03 — FOOD AI

- Câmera mobile.
- Upload de imagens.
- Storage privado.
- Processamento assíncrono.
- Abstração do provedor multimodal.
- Identificação de alimentos.
- Estimativa de porções.
- Integração com bases nutricionais.
- Cálculo nutricional.
- Apresentação de incerteza.
- Confirmação e correção.
- Histórico de refeições.
- Testes de avaliação da IA.

Critério de aceite: uma fotografia percorre todo o pipeline, produz uma estimativa estruturada e pode ser registrada e corrigida.

## FASE 04 — STRAVA INTEGRATION

- Aplicação Strava.
- OAuth.
- Conexão.
- Tokens.
- Webhooks.
- Importação de atividades.
- Atualizações.
- Exclusões.
- Sincronização inicial.
- Histórico.
- Recuperação de falhas.
- Desconexão.

Critério de aceite: atividades autorizadas são importadas de forma confiável, sem duplicações e com suporte ao ciclo de vida da integração.

## FASE 05 — GOALS ENGINE

- Cadastro de objetivos.
- Metas personalizadas.
- Planejamento semanal.
- Check-ins.
- Progressão.
- Regras de conclusão.
- Histórico.
- Adaptação à rotina.

Priorize consistência, atividades adequadas e hábitos saudáveis. Não desenvolva mecanismos de restrição alimentar ou compensação por exercícios.

Critério de aceite: objetivos podem ser configurados, acompanhados e validados por regras reproduzíveis.

## FASE 06 — GAMIFICATION ENGINE

- XP.
- Níveis.
- Missões.
- Conquistas.
- Recompensas.
- Sequências de consistência.
- Eventos.
- Histórico.
- Proteção contra duplicidade.
- Feedback visual.

Critério de aceite: eventos legítimos geram progressão auditável e não permitem concessão duplicada de recompensas.

## FASE 07 — MOBILE & WEB EXPERIENCE

- Dashboard mobile.
- Dashboard web.
- Navegação.
- Câmera.
- Histórico.
- Atividades.
- Metas.
- Missões.
- Conquistas.
- Gráficos.
- Calendário.
- Configurações.
- Responsividade.
- Acessibilidade.

O desenvolvimento das interfaces deverá acompanhar as fases anteriores através de entregas verticais. Esta fase consolida a experiência completa e a consistência visual entre plataformas.

Critério de aceite: os principais fluxos do produto funcionam de ponta a ponta nas duas plataformas.

## FASE 08 — INTELLIGENCE & PERSONALIZATION

- Relatórios semanais.
- Análises de consistência.
- Identificação de padrões.
- Recomendações de hábitos.
- Notificações.
- Personalização de missões.
- Insights.
- Histórico evolutivo.

As recomendações não deverão apresentar diagnósticos médicos nem incentivar comportamentos alimentares ou esportivos prejudiciais.

Critério de aceite: insights são baseados em dados reais, contextualizados, explicáveis e não apresentam inferências indevidas.

## FASE 09 — PRODUCTION READINESS & LAUNCH

- Segurança.
- Performance.
- Escalabilidade.
- Testes de integração.
- Testes end-to-end.
- Acessibilidade.
- Revisão de privacidade.
- LGPD.
- Monitoramento.
- Backups.
- Recuperação.
- Deploy.
- Documentação operacional.
- Preparação para beta.
- Checklist de lançamento.

Critério de aceite: o produto possui evidências de qualidade, segurança, disponibilidade e operação suficientes para o lançamento controlado.

---

# 7. COMO O HARNESS DEVE ORQUESTRAR O CLAUDE

Essa é uma das partes mais importantes.

O harness precisa estabelecer um protocolo obrigatório para todas as próximas sessões.

## 7.1 Início de uma fase

Quando eu solicitar:

"Vamos iniciar a fase 03"

O Claude deverá:

1. Ler `CLAUDE.md`.
2. Consultar as rules pertinentes.
3. Ler o roadmap.
4. Ler o documento completo da fase.
5. Consultar as ADRs relacionadas.
6. Identificar dependências concluídas.
7. Verificar o estado atual do repositório.
8. Carregar as skills relevantes do Superpowers.
9. Utilizar brainstorming para resolver questões de design ainda abertas.
10. Gerar um plano detalhado utilizando `writing-plans`.
11. Definir os critérios de aceite e os testes.
12. Apresentar o plano antes de começar a implementação.

Não repetir perguntas já respondidas na documentação.

Não presumir que uma fase está pronta porque a anterior foi declarada concluída. Verificar evidências.

## 7.2 Durante a implementação

Aplicar:

- Test-Driven Development.
- RED → GREEN → REFACTOR.
- Revisões frequentes.
- Separação de responsabilidades.
- Commits pequenos quando autorizados.
- Tratamento de erros.
- Testes de regressão.
- Documentação atualizada.

Utilizar subagents quando trouxerem benefício concreto.

Cada subagent deverá ter uma responsabilidade específica e receber contexto suficiente.

Para tarefas adequadas, utilizar `subagent-driven-development`, com revisão de conformidade da implementação e revisão de qualidade.

Não delegar tarefas conflitantes sobre os mesmos arquivos sem coordenar as alterações.

## 7.3 Finalização de uma fase

Antes de declarar uma fase concluída:

1. Executar os testes.
2. Executar lint.
3. Executar verificações de tipos.
4. Verificar segurança aplicável.
5. Revisar arquitetura.
6. Revisar requisitos.
7. Executar `verification-before-completion`.
8. Atualizar documentação.
9. Atualizar o roadmap.
10. Produzir relatório de conclusão.

Utilizar `requesting-code-review` e `finishing-a-development-branch` conforme o fluxo do Superpowers.

Nenhuma fase poderá ser declarada concluída apenas porque os arquivos foram criados.

É necessária evidência verificável.

## 7.4 Controle de fases

Implemente no harness um mecanismo documental para acompanhar:

- Não iniciada.
- Em planejamento.
- Em desenvolvimento.
- Em revisão.
- Bloqueada.
- Concluída.

Cada mudança de estado deve ter evidência e data.

O Claude não poderá avançar automaticamente para uma nova fase quando a fase atual estiver concluída.

Deverá apresentar o relatório e aguardar minha autorização para iniciar a próxima fase.

---

# 8. PADRÕES OBRIGATÓRIOS DE ENGENHARIA

Crie regras específicas para:

## Backend

- SOLID quando aplicável.
- DRY.
- YAGNI.
- Separação de domínio e infraestrutura.
- Services com responsabilidades claras.
- Controllers enxutos.
- Queries eficientes.
- Transações.
- Idempotência.
- Tratamento centralizado de erros.
- RSpec.
- RuboCop.
- Brakeman e auditorias de dependências.

## Frontend e Mobile

- TypeScript.
- Componentização.
- Separação entre estado e apresentação.
- Tratamento consistente de loading, empty e error states.
- Acessibilidade.
- Testes de componentes.
- Validação de formulários.
- Gerenciamento seguro de credenciais.
- Testes dos fluxos principais.

## Database

- Constraints no banco.
- Índices justificados.
- Integridade referencial.
- Migrations reversíveis quando possível.
- Evitar N+1.
- Evitar consultas desnecessárias.
- Paginação.
- Controle de concorrência.

## Qualidade

- Nenhuma implementação sem critérios de aceite.
- Nenhuma funcionalidade sem testes proporcionais ao risco.
- Nenhuma afirmação de teste aprovado sem executar o comando.
- Nenhum TODO crítico sem responsável e justificativa.
- Nenhuma dependência adicionada sem justificativa.
- Nenhum segredo versionado.
- Nenhuma alteração arquitetural importante sem ADR.

---

# 9. CONSTRUÇÃO DAS SKILLS E SUBAGENTS ESPECÍFICOS

Crie somente extensões que realmente agreguem valor à metodologia existente.

## Skills

### phase-kickoff

Skill responsável por preparar o início de cada fase.

Deve localizar e ler o planejamento, validar dependências, verificar o estado do código e preparar a execução usando Superpowers.

### phase-closeout

Skill responsável pelo encerramento de cada fase.

Deve executar o checklist, consolidar evidências, atualizar os documentos e gerar relatório.

Essas skills complementam o Superpowers. Não devem substituir `writing-plans`, TDD ou revisão de código.

## Subagents

### software-architect

Responsável por revisar arquitetura, modularidade, dependências e decisões técnicas.

### backend-reviewer

Especialista em Ruby, Rails, PostgreSQL, Sidekiq e qualidade do backend.

### frontend-mobile-reviewer

Especialista em React, TypeScript, Expo e experiência do usuário.

### security-reviewer

Responsável por segurança, LGPD, privacidade e proteção dos dados.

### qa-reviewer

Responsável por estratégia de testes, critérios de aceite, regressões e evidências.

Configure cada agent com instruções específicas, responsabilidades limitadas e permissões adequadas ao seu trabalho.

Não dê permissões excessivas.

---

# 10. DOCUMENTAÇÃO E RASTREABILIDADE

Cada requisito deve receber um identificador.

Exemplos:

```text
FR-FOOD-001
FR-FOOD-002
FR-STRAVA-001
FR-GOALS-001
FR-GAME-001

NFR-SEC-001
NFR-PERF-001
NFR-PRIVACY-001
```

Os documentos deverão permitir rastrear:

```text
Requisito
   |
   v
Decisão arquitetural
   |
   v
Fase
   |
   v
Tarefa
   |
   v
Implementação
   |
   v
Teste
   |
   v
Critério de aceite
```

Toda decisão técnica relevante deverá possuir uma ADR com:

- Contexto.
- Problema.
- Alternativas.
- Decisão.
- Justificativa.
- Consequências.
- Estado da decisão.

Não registre decisões hipotéticas como definitivas.

Quando ainda houver dúvidas técnicas, documente as alternativas e a forma de validá-las.

---

# 11. PESQUISA E VALIDAÇÃO TÉCNICA

Sempre que uma decisão depender de informação externa ou de uma versão específica:

1. Consulte a documentação oficial.
2. Confirme a versão atual.
3. Verifique compatibilidade.
4. Registre a fonte.
5. Registre a data da consulta.
6. Não invente capacidades de APIs ou bibliotecas.

Priorize:

- Documentação oficial Ruby.
- Documentação oficial Rails.
- Documentação React.
- Documentação Expo.
- Documentação PostgreSQL.
- Documentação Strava.
- Documentação do provedor de IA.
- Documentação oficial das bases nutricionais.

Para decisões sobre APIs externas, não utilize apenas artigos antigos ou exemplos de terceiros.

---

# 12. AUTOMAÇÃO E VERIFICAÇÃO DO HARNESS

Crie um script:

`scripts/verify-harness.sh`

Ele deverá verificar, no mínimo:

- Presença dos documentos obrigatórios.
- Presença de CLAUDE.md.
- Presença das rules.
- Presença das skills do projeto.
- Presença dos agents.
- Existência dos documentos de todas as fases.
- Integridade dos principais links internos da documentação, quando tecnicamente viável.

Se existir ferramenta de Markdown lint adequada, avalie sua utilização.

Não crie mecanismos complexos sem necessidade.

O script deverá retornar código de saída diferente de zero quando encontrar uma falha crítica.

Se configurar hooks do Claude Code, utilize a documentação oficial da versão instalada. Prefira verificações determinísticas e seguras. Não configure permissões globais irrestritas nem comandos destrutivos automáticos.

---

# 13. RESTRIÇÕES DESTA SESSÃO

É extremamente importante respeitar o escopo.

Nesta sessão:

**VOCÊ ESTÁ AUTORIZADO A:**

- Inspecionar o repositório.
- Consultar documentação.
- Utilizar as skills do Superpowers.
- Definir arquitetura.
- Criar documentação.
- Criar CLAUDE.md.
- Criar rules.
- Criar skills específicas do projeto.
- Criar agents.
- Criar configurações do harness.
- Criar o roadmap.
- Criar as especificações completas das fases.
- Criar scripts de validação do harness.

**VOCÊ NÃO ESTÁ AUTORIZADO A:**

- Implementar o backend funcional.
- Implementar o aplicativo mobile.
- Implementar o dashboard.
- Criar migrations de domínio.
- Criar endpoints de negócio.
- Implementar integração real com Strava.
- Integrar um provedor de IA.
- Instalar dependências de runtime sem necessidade.
- Implementar funcionalidades das fases futuras.

Não confunda criação do harness com desenvolvimento do aplicativo.

A Fase 00 deve preparar tudo para que as fases seguintes possam ser executadas de maneira organizada e reproduzível.

Não faça commits automaticamente.

---

# 14. CRITÉRIOS FINAIS DE ACEITE DA FASE 00

Considere esta fase concluída somente quando:

- [ ] O Superpowers foi identificado e utilizado conforme disponível.
- [ ] O repositório foi inspecionado.
- [ ] A visão do produto está documentada.
- [ ] O PRD está documentado.
- [ ] A arquitetura geral está documentada.
- [ ] O modelo de domínio está documentado.
- [ ] O desenho inicial do banco está documentado.
- [ ] A arquitetura Food AI está documentada.
- [ ] A integração Strava está documentada.
- [ ] A arquitetura de gamificação está documentada.
- [ ] As decisões arquiteturais iniciais estão registradas.
- [ ] As nove fases estão detalhadas.
- [ ] Cada fase possui critérios de aceite.
- [ ] O protocolo de execução está documentado.
- [ ] O CLAUDE.md está configurado.
- [ ] As rules estão organizadas.
- [ ] Os agents estão definidos.
- [ ] As skills complementares estão definidas.
- [ ] O script de verificação está criado.
- [ ] O harness passou pela verificação.
- [ ] A documentação foi revisada.
- [ ] Não existem funcionalidades do produto implementadas antecipadamente.

---

# 15. ENTREGA FINAL

Ao concluir a Fase 00, apresente um relatório contendo:

## A. Resumo executivo

O que foi criado e como o harness irá governar o projeto.

## B. Arquitetura

Explique as escolhas arquiteturais, os domínios e os principais fluxos.

## C. Estrutura do repositório

Apresente a árvore dos arquivos criados.

## D. Funcionamento do Superpowers

Informe quais skills foram efetivamente utilizadas e como elas serão utilizadas nas próximas fases.

## E. Roadmap

Apresente todas as fases, suas dependências e critérios de aceite.

## F. Validação

Liste os comandos efetivamente executados e seus resultados.

Diferencie arquivos verificados de arquivos apenas criados.

## G. Pendências

Liste dúvidas técnicas, riscos e decisões que ainda precisam ser confirmadas.

## H. Próximo passo

Informe exatamente qual instrução devo fornecer para iniciar a Fase 01.

Não inicie a Fase 01 automaticamente.

---

# INSTRUÇÃO FINAL

Pense como um Principal Engineer construindo a fundação de um produto que deverá evoluir durante anos.

Não tente impressionar com complexidade desnecessária.

Priorize:

1. Clareza arquitetural.
2. Simplicidade.
3. Modularidade.
4. Segurança.
5. Testabilidade.
6. Rastreabilidade.
7. Escalabilidade quando necessária.
8. Qualidade de execução.
9. Consistência entre sessões do Claude Code.
10. Autonomia controlada do agente.

O harness deve ser suficientemente completo para que qualquer nova sessão do Claude Code compreenda o projeto sem depender da memória de sessões anteriores.

**Construa primeiro o sistema de engenharia. Depois, com minha autorização, começaremos a construir o produto.**
