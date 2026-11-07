# Visão geral do sistema

Descreve a arquitetura pretendida. **Em código, por ora, só existe o esqueleto da Fase 01:** API com saúde, logs e erro central, Sidekiq, contrato, CI e uma tela de estado em cada cliente. Os domínios são diretórios reservados, sem código. Versões em [ADR 0002](decisions/0002-technology-baseline.md).

## Decisão central

Um **monólito modular em Rails**, com domínios separados por namespace, atendendo dois clientes. Um único desenvolvedor mantém tudo, então cada parte móvel a mais custa caro ([ADR 0001](decisions/0001-modular-monolith-monorepo.md)).

```mermaid
flowchart LR
  M[App mobile<br/>Expo + TypeScript] -->|REST + OpenAPI| API
  W[Painel web<br/>React + Vite] -->|REST + OpenAPI| API
  M -->|URL assinada| S3[(Armazenamento<br/>privado de fotos)]
  subgraph Backend [Rails API - monólito modular]
    API[Controllers] --> D[Domínios]
    D --> OB[(Outbox)]
    J[Sidekiq] --> D
    OB --> J
  end
  D --> PG[(PostgreSQL)]
  J --> R[(Valkey)]
  J -->|adaptador| IA[Provedor de IA]
  J -->|adaptador| NB[Bases nutricionais]
  J --> STV[API do Strava]
  STV -->|webhook| API
  J --> PUSH[Serviço de push]
```

## Monorepo

```text
apps/api          Rails API: toda a regra de negócio
apps/web          Painel React
apps/mobile       App Expo
packages/contracts  OpenAPI e tipos gerados (ADR 0014)
docs/             Documentação e planejamento
scripts/          Verificações do harness e automações
docker-compose.yml  PostgreSQL e Valkey para desenvolvimento
.claude/          Rules, agents e skills do projeto
```

Sem pasta `docker/` por enquanto: os serviços usam imagens oficiais, e a imagem da API entra com o deploy, no M1.

## Responsabilidades

| Parte | Faz | Não faz |
|---|---|---|
| `apps/api` | Regra de negócio, autorização, persistência, jobs, integrações | Renderizar telas |
| `apps/web` e `apps/mobile` | Apresentação, estado de tela, validação de formulário para dar retorno rápido | Decidir regra de negócio, calcular XP, nutrição ou conclusão de meta |
| `packages/contracts` | Fonte dos contratos da API e tipos gerados | Conter lógica |

O backend é a fonte central da lógica. Se os dois clientes precisam calcular a mesma coisa, ela pertence à API.

## Fluxos principais

### Foto até o registro da refeição

```mermaid
sequenceDiagram
  participant App
  participant API
  participant S3 as Armazenamento
  participant Job as Sidekiq
  participant IA as Provedor de IA
  App->>API: Pede autorização de envio (verifica consentimento e limite)
  API-->>App: URL assinada e id da refeição
  App->>S3: Envia a foto
  App->>API: Confirma o envio
  API->>Job: Enfileira a análise
  Job->>IA: Imagem e prompt versionado
  IA-->>Job: JSON estruturado
  Job->>Job: Valida schema de itens e porções
  Job->>API: food_analysis.completed
  API->>API: Nutrition consulta o catálogo e calcula as faixas
  App->>API: Consulta o resultado e confirma
  API->>API: food_entry.confirmed na outbox
```

Detalhes em [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md).

### Webhook do Strava até o XP

```mermaid
sequenceDiagram
  participant STV as Strava
  participant API
  participant Job as Sidekiq
  participant ACT as Activities
  participant GAME as Gamification
  STV->>API: Evento (responde 200 em até 2 s)
  API->>Job: Grava o evento e enfileira
  Job->>STV: Busca a atividade
  Job->>ACT: Cria ou atualiza sem duplicar
  ACT->>GAME: activity.imported via outbox
  GAME->>GAME: Aplica regras e grava no livro-razão de forma idempotente
```

Detalhes em [STRAVA_INTEGRATION.md](STRAVA_INTEGRATION.md) e [GAMIFICATION_ARCHITECTURE.md](GAMIFICATION_ARCHITECTURE.md).

## Atributos de qualidade e como a arquitetura responde

| Atributo | Resposta |
|---|---|
| Simplicidade para um desenvolvedor | Um deploy, um banco, um processo de jobs |
| Evolução dos domínios | Limites por namespace, comunicação por eventos, regras verificadas em teste ([ADR 0003](decisions/0003-domain-boundaries-without-engines.md)) |
| Consistência entre domínios | Outbox transacional e consumidores idempotentes ([ADR 0004](decisions/0004-domain-events-transactional-outbox.md)) |
| Troca de provedores | Adaptadores para IA e bases nutricionais ([ADR 0006](decisions/0006-food-ai-pipeline-and-provider-abstraction.md), [ADR 0007](decisions/0007-nutrition-data-sources.md)) |
| Privacidade | Consentimento por finalidade, armazenamento privado, cifragem, retenção automática ([PRIVACY_AND_LGPD.md](../security/PRIVACY_AND_LGPD.md)) |
| Crescimento | Sidekiq e Rails escalam horizontalmente. Um domínio só vira serviço com evidência real de necessidade |

## O que deliberadamente não existe

- **Microsserviços:** nenhum domínio tem hoje uma necessidade de escala ou de equipe que justifique.
- **Rails Engine por domínio:** o custo de configuração não se paga sem uma justificativa concreta.
- **GraphQL:** REST com OpenAPI atende aos dois clientes.
- **Broker de eventos externo:** a outbox com Sidekiq basta enquanto há um único processo produtor e consumidor.
- **Lógica de negócio nos clientes:** ver a tabela de responsabilidades.

Mudar qualquer um destes itens exige uma nova ADR.
