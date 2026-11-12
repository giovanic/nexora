# Instruções do projeto

SaaS de bem-estar com gamificação: foto da refeição vira estimativa nutricional honesta, com metas de hábito, atividades (Strava) e evolução pessoal. "Fitness Companion" é nome de trabalho, e `nexora` é só o diretório. Nenhum dos dois é marca.

Desenvolvedor único: o **responsável pelo produto**, que aprova cada avanço. Comunicação com ele em português do Brasil.

## Antes de qualquer trabalho

1. **Superpowers é obrigatório.** Use `superpowers:using-superpowers`. Versão validada: 7.0.0.
   - **Se as skills não estiverem disponíveis, pare.** Informe o bloqueio e o comando abaixo. Nunca simule uma skill nem diga que a usou.
   - `claude plugin install superpowers@claude-plugins-official --scope project`, e depois `/reload-plugins` ou nova sessão.
2. **Veja em que ponto o projeto está** em [STATUS.md](docs/roadmap/STATUS.md). É a fonte única. Não confie em memória de sessões anteriores.

## Pedidos sobre fases

| Pedido | O que fazer |
|---|---|
| "Vamos iniciar a fase NN" ou continuar uma linha em andamento | Usar a skill `phase-kickoff` |
| Fase pronta, encerrar | Usar a skill `phase-closeout` |
| Dúvida sobre como executar | [Protocolo](docs/roadmap/PHASE_EXECUTION_PROTOCOL.md) |

## Regras invioláveis

**Controle**

- **Nenhuma fase avança sem autorização do responsável,** mesmo com a anterior concluída. Apresente o relatório e pare.
- **Trabalhe só na fase autorizada.** Não implemente funcionalidades de fases futuras.
- **Apresente o plano antes de implementar.**
- **Sem commit ou push sem autorização.**
- **Sem comandos destrutivos sem autorização.** Preserve alterações locais.

**Evidência**

- **Nenhuma afirmação de que algo passa ou funciona sem executar o comando.** Use `superpowers:verification-before-completion`.
- **Fase declarada pronta não é fase pronta.** Verifique evidências das dependências.
- **Fatos externos** (APIs, versões, licenças, preços) vêm da fonte oficial, com data, no [registro de fontes](docs/architecture/EXTERNAL_SOURCES.md). O que não foi verificado continua marcado assim.

**Engenharia**

- **TDD em todo código de produto.**
- **Mudança arquitetural importante exige ADR.** Decisão hipotética não aparece como definitiva.
- **Dependência nova exige justificativa.** Nenhum segredo versionado.
- **Regra de negócio fica no backend.** Domínios não leem tabelas uns dos outros.

**Produto: só o responsável pode mudar, por ADR**

- **Sem meta nem teto de calorias.** Calorias aparecem só como estimativa em faixa.
- **XP nunca usa** calorias consumidas ou queimadas, déficit, peso ou volume absoluto. Sem premiar restrição ou excesso.
- **Estimativa nunca aparece como medição.** O modelo de IA não é a fonte das calorias.
- **Dados do Strava são visíveis só ao dono,** e não vão para provedores de IA. Sem ranking com eles. Sem replicar o Strava.
- **TBCA e TACO não podem ser usadas** sem licença verificada. O nível gratuito do Gemini é proibido.
- **MVP só para adultos.** Não é ferramenta médica: sem diagnóstico, tratamento ou prescrição.
- **Fotos e dados de saúde nunca em logs.** Consentimento específico antes de enviar foto à IA.
- **Fora do roadmap:** ranking, cobrança, modo adolescente. Não implemente sem decisão registrada.

## Mapa de documentos

Leia o que a tarefa pedir, sem carregar tudo.

| Precisa de | Leia |
|---|---|
| O que é o produto e para quem | [Visão](docs/product/PRODUCT_VISION.md), [PRD](docs/product/PRD.md) |
| Requisitos com IDs | [Requisitos](docs/product/FUNCTIONAL_REQUIREMENTS.md), [Matriz](docs/roadmap/TRACEABILITY.md) |
| Cenários de uso | [Jornadas](docs/product/USER_JOURNEYS.md) |
| Arquitetura geral | [Visão geral](docs/architecture/SYSTEM_OVERVIEW.md), [Domínios](docs/architecture/DOMAIN_MODEL.md) |
| Banco e API | [Banco](docs/architecture/DATABASE_DESIGN.md), [API](docs/architecture/API_DESIGN.md) |
| Food AI, Strava, gamificação | [IA](docs/architecture/AI_ARCHITECTURE.md), [Strava](docs/architecture/STRAVA_INTEGRATION.md), [Gamificação](docs/architecture/GAMIFICATION_ARCHITECTURE.md) |
| Decisões | [ADRs](docs/architecture/decisions/README.md) |
| Segurança, LGPD, saúde | [Segurança](docs/security/SECURITY.md), [LGPD](docs/security/PRIVACY_AND_LGPD.md), [Saúde](docs/security/HEALTH_DATA_SAFETY.md) |
| Como escrever e testar | [Padrões](docs/engineering/CODING_STANDARDS.md), [Testes](docs/engineering/TESTING_STRATEGY.md), [Pronto](docs/engineering/DEFINITION_OF_DONE.md) |
| CI e observabilidade | [CI/CD](docs/engineering/CI_CD.md), [Observabilidade](docs/engineering/OBSERVABILITY.md) |
| Fases e ordem | [Roadmap](docs/roadmap/ROADMAP.md), documentos em [`docs/roadmap/phases/`](docs/roadmap/phases/) |
| Ambiente e liberação | [Local](docs/operations/LOCAL_DEVELOPMENT.md), [Variáveis](docs/operations/ENVIRONMENT_VARIABLES.md), [Checklists](docs/operations/RELEASE_CHECKLIST.md) |
| Origem de tudo | [Master Prompt](docs/product/MASTER_PROMPT.md), [Design da Fase 00](docs/superpowers/specs/2026-11-05-engineering-harness-design.md) |

## Verificação do harness

```bash
bash scripts/verify-harness.sh
bash scripts/test-verify-harness.sh
```

Rode ao mudar a documentação, e sempre no encerramento de fase. Código de saída diferente de zero significa problema real.


## Convenções

- Documentação em português do Brasil; identificadores, eventos, tabelas e nomes de arquivo em inglês.
- Agents revisores (`software-architect`, `backend-reviewer`, `frontend-mobile-reviewer`, `security-reviewer`, `qa-reviewer`) só apontam problemas, e não alteram arquivos.
- Rules em `.claude/rules/` carregam sozinhas conforme o caminho.
