# Estratégia de testes

## Regras fundamentais

1. **TDD é obrigatório** em código de produto: RED, GREEN, REFACTOR, com `superpowers:test-driven-development`.
2. **Nenhuma afirmação sem execução.** "Os testes passam" só depois de rodar o comando e ler a saída, usando `superpowers:verification-before-completion`.
3. **Teste proporcional ao risco.** Mais rigor onde o erro causa dano.
4. **Testar comportamento,** não implementação nem mocks.
5. **Bug corrigido tem teste de regressão** que falhou antes da correção, usando `superpowers:systematic-debugging`.

## Níveis

| Nível | Ferramenta | O que cobre | Roda |
|---|---|---|---|
| Unidade | RSpec; Vitest na web; `jest-expo` no mobile | Serviços, cálculos, regras, componentes de apresentação | Sempre |
| Requisição | RSpec request specs | Rotas, autorização, formato de erro, contrato | Sempre |
| Integração | RSpec com um processo `sidekiq` real (`spec/support/sidekiq_process.rb`) | Pipeline e eventos ponta a ponta no backend | Sempre |
| Componentes | Testing Library | Estados, interação, acessibilidade | Sempre |
| Limites de domínio | `spec/architecture`, com o Prism ([ADR 0003](../architecture/decisions/0003-domain-boundaries-without-engines.md)) | Violações de dependência | Sempre |
| Contrato | `openapi_first` em request specs, e `expect_response_to_match_contract` ([ADR 0014](../architecture/decisions/0014-api-contract-tooling.md)) | Implementação contra o OpenAPI | Sempre |
| End-to-end | A definir nas Fases 07 e 09 | Fluxos principais em web e mobile | Antes de liberar |
| Avaliação de IA | Script próprio | Qualidade, custo e latência | Ao mudar prompt, modelo ou provedor |
| Carga | A definir na Fase 09 | Capacidade de lançamento | Fase 09 |

As ferramentas foram confirmadas por execução na Fase 01. A suíte da API precisa de PostgreSQL e Valkey reais, inclusive no CI.

## Testes obrigatórios por risco

### Isolamento entre usuários

Cada recurso tem um teste em que outra pessoa recebe `404` e nada é alterado. Teste que percorre as rotas identifica recurso novo sem cobertura.

### Idempotência e concorrência

| Caso | Prova |
|---|---|
| Evento repetido | Efeito aplicado uma só vez |
| Mesmo evento em dois workers | Execução concorrente real, com um único lançamento em `xp_transactions` |
| Webhook repetido | Uma só atividade |
| Renovação simultânea do token | Só uma chamada, novo token salvo |
| Envio repetido da foto | Uma só refeição |

Testes de concorrência usam banco real, sem transação envolvente.

### Segurança de produto

- Tipos de meta proibidos são rejeitados na API e no banco.
- Toda regra de XP, missão e conquista passa pelo teste de critérios proibidos.
- Estimativas sempre trazem faixa e `is_estimate: true`.
- Textos estáticos passam pela lista de linguagem.

### Privacidade

- Excluir a conta remove tudo de todas as tabelas: um teste percorre as tabelas com `user_id`.
- Sem consentimento, a rota responde `403` e nenhum dado vai ao provedor.
- Logs de um fluxo completo não contêm token, URL assinada nem conteúdo de refeição.
- Revogar consentimento interrompe o tratamento.

### Limites do Strava

- Dados de um atleta não aparecem para outro.
- 429 adia o trabalho, sem perda.
- Rotação do refresh token é salva antes do uso.

## APIs externas

- **Nunca** chamadas reais na suíte comum: elas são lentas, custam e não são determinísticas.
- **Dublês na fronteira do adaptador,** com respostas baseadas no formato oficial, ou gravadas com dados sanitizados.
- **Teste contratual do adaptador,** executado manualmente e registrado, contra o provedor real, ao mudar de versão.
- **Sem segredos ou dados pessoais** em respostas gravadas.
- Um dublê não prova que o provedor se comporta assim. O plano da fase inclui ao menos uma demonstração real, com evidência registrada.

## Avaliação de IA

Separada da suíte comum, pois custa dinheiro e não é determinística. Dataset e métricas estão em [AI_ARCHITECTURE.md](../architecture/AI_ARCHITECTURE.md). O resultado de cada execução fica registrado, com versão do prompt, modelo e data. A suíte comum usa dublês para validar o restante do pipeline.

## Dados de teste

Sem dados reais de usuários. Fábricas por contexto. Datas e fusos fixos. Testes que atravessam a meia-noite em fusos diferentes em tudo que usa `local_date`.

## Cobertura

Não há meta numérica como fim em si. Cobertura serve para encontrar lacunas. Código de risco alto precisa de testes dos casos acima, independentemente de percentual.

## O que conta como evidência

O comando executado, seu código de saída e o resultado, registrados no relatório da fase. Evidência de telas: captura ou gravação, além do teste automático. Ver [DEFINITION_OF_DONE.md](DEFINITION_OF_DONE.md).

## O harness

O próprio harness é testado: `scripts/test-verify-harness.sh` prova que `scripts/verify-harness.sh` reprova cada defeito.
