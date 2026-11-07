# Padrões de código

Complementa as rules em `.claude/rules/`. Convenções concretas são ajustadas na Fase 01, quando existir código.

## Princípios gerais

- **YAGNI:** só o que a fase atual exige. Sem abstração para um segundo caso que não existe.
- **DRY:** evitar duplicar conhecimento, sem criar abstração prematura para código parecido por acaso.
- **SOLID quando ajudar**, nunca como cerimônia.
- **Dependência nova exige justificativa** no plano da fase: por que é necessária, alternativa sem ela, estado de manutenção e licença.
- **`TODO` crítico só com responsável e justificativa.** Sem isso, resolva ou registre como risco.
- **Identificadores em inglês, documentação em português do Brasil.**
- **Comentários explicam o porquê**, não o que o código já diz.
- **Segredos, dados de saúde e tokens nunca aparecem em logs.**

## Backend: Ruby e Rails

### Estrutura

```text
apps/api/app/domains/nutrition/
  api.rb                  API pública do contexto
  models/                 Modelos do contexto
  services/               Casos de uso
  events/                 Definição de eventos publicados
  consumers/              Consumidores de eventos
  adapters/               Infraestrutura externa
apps/api/app/controllers/api/v1/
```

A estrutura final é confirmada na [ADR 0003](../architecture/decisions/0003-domain-boundaries-without-engines.md).

### Regras

- **Controllers enxutos:** autenticam, autorizam, chamam um serviço e serializam. Sem regra de negócio.
- **Services:** uma responsabilidade, entrada explícita e resultado claro. Nome é verbo: `ConfirmFoodEntry`.
- **Domínio separado de infraestrutura:** clientes HTTP ficam em `adapters/`. O domínio conhece uma interface.
- **Sem acesso entre contextos** a modelos ou tabelas. Use `<Contexto>::Api` ou eventos.
- **Transações** em volta de toda escrita que precisa ser atômica, incluindo a outbox. Nunca chamada externa dentro de transação.
- **Jobs idempotentes,** recebendo identificadores, não objetos. Reexecutar não muda o resultado.
- **Erros tratados de forma central,** com o formato de [API_DESIGN.md](../architecture/API_DESIGN.md). Exceções de domínio têm classe própria.
- **Sem callbacks de modelo com efeito externo.** Efeitos ficam em serviços e eventos.
- **Sem lógica em `after_commit`** que não seja publicar para a fila, sempre com tratamento de falha.

### Ferramentas

RSpec, RuboCop, Brakeman e auditoria de gems. Versões decididas na Fase 01.

## Banco de dados

- **A regra vale no banco:** `NOT NULL`, `CHECK`, `UNIQUE` e chaves estrangeiras onde couber, não só validação de modelo.
- **Índice precisa de justificativa:** uma consulta real que o use.
- **Migrations reversíveis quando possível.** Quando não for, explique no arquivo.
- **Migrations seguras em produção:** sem bloqueio longo; separar criação de coluna, preenchimento e `NOT NULL`, a partir do M1.
- **Sem N+1:** verificado em teste. Mas meça antes de otimizar: conte as consultas com N e 3N.
- **Listagens sempre paginadas,** com limite máximo.
- **Concorrência:** índice único é a última linha de defesa; bloqueio otimista ou pessimista onde houver disputa ([exemplos](../architecture/DATABASE_DESIGN.md)).
- **Estimativas em faixa,** nunca coluna única que pareça medição.

## Frontend e mobile: TypeScript

### Estrutura

```text
apps/web/src/features/<feature>/   Telas e componentes de uma funcionalidade
apps/web/src/shared/               Componentes reutilizados de verdade
apps/mobile/src/features/<feature>/
```

A estrutura final é confirmada na Fase 01.

### Regras

- **TypeScript estrito,** sem `any` sem justificativa.
- **Tipos da API vêm do contrato** ([ADR 0014](../architecture/decisions/0014-api-contract-tooling.md)), nunca escritos à mão.
- **Sem regra de negócio no cliente.** XP, nutrição e conclusão de metas vêm do backend.
- **Separar estado e apresentação:** componentes de apresentação recebem dados por props; hooks ou contêineres buscam dados.
- **Três estados sempre:** carregando, vazio e erro. Toda tela tem os três, testados.
- **Formulários validados,** com mensagem acessível. A validação definitiva é do backend.
- **Acessibilidade desde a primeira tela:** rótulos, contraste, foco e área de toque.
- **Credenciais:** cookie `HttpOnly` na web; armazenamento seguro no mobile. Nunca em `localStorage` nem `AsyncStorage`.
- **Sem segredo no cliente:** nada de chave de IA ou segredo do Strava em variável `VITE_` ou `EXPO_PUBLIC_`.
- **Textos** seguem a lista de [segurança de saúde](../security/HEALTH_DATA_SAFETY.md).

### Ferramentas

ESLint, Prettier (ou equivalente), checagem de tipos e testes de componente. Versões decididas na Fase 01.

## Mudanças arquiteturais

Mudança arquitetural importante exige ADR antes do código. Exemplos: nova dependência estrutural, novo contexto, mudar a comunicação entre contextos, afrouxar uma regra de segurança.
