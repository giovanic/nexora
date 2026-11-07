# Fase 03 — Food AI

- **Estado:** ver [STATUS.md](../STATUS.md)
- **Requisitos:** FR-FOOD-001, FR-FOOD-002, FR-FOOD-003, FR-FOOD-004, FR-FOOD-005, FR-FOOD-006, FR-FOOD-007, FR-FOOD-008, FR-FOOD-009, FR-FOOD-010, FR-FOOD-011, FR-FOOD-012, FR-FOOD-013, FR-FOOD-014, FR-FOOD-015, FR-CATALOG-001, FR-CATALOG-002, FR-CATALOG-003, FR-CATALOG-004, FR-MOBILE-001, FR-MOBILE-002, NFR-SEC-002, NFR-PRIVACY-001, NFR-PRIVACY-004, NFR-PRIVACY-005, NFR-SAFETY-001, NFR-SAFETY-002, NFR-SAFETY-003, NFR-SAFETY-004, NFR-PERF-002, NFR-PERF-003, NFR-COST-001, NFR-COST-002, NFR-COST-003
- **ADRs:** [0006](../../architecture/decisions/0006-food-ai-pipeline-and-provider-abstraction.md), [0007](../../architecture/decisions/0007-nutrition-data-sources.md), [0011](../../architecture/decisions/0011-no-calorie-goals.md)
- **Arquitetura:** [AI_ARCHITECTURE.md](../../architecture/AI_ARCHITECTURE.md)

## Objetivo

Uma foto percorre todo o pipeline e produz uma estimativa nutricional estruturada e honesta, que a pessoa confirma ou corrige, com custo medido. É o coração do primeiro entregável.

## Escopo

**Inclui:** contextos Nutrition, Food AI e Food Catalog; câmera; envio por URL assinada; armazenamento privado; processamento assíncrono; adaptador de provedor; composições de pratos brasileiros; cálculo em faixa; confirmação; correção; histórico; registro manual; limite de análises; dataset de avaliação; telas móveis mínimas.

**Não inclui:** meta de calorias, painel web de refeições (Fase 07), uso de fotos de usuários para avaliação, integração com dados do Strava, ou TBCA e TACO sem licença verificada.

## Funcionalidades

- **Câmera e galeria** no app, com tratamento de permissão negada e falha de rede sem perder a foto.
- **Envio:** autorização verifica consentimento `food_photo_ai` e limite; URL assinada com validade de até 15 minutos; validação do objeto real após o envio.
- **Pipeline:** validação e remoção de EXIF no objeto guardado; normalização; adaptador com envio inline; validação de saída; `food_analysis.completed`. Nutrition faz a correspondência com o catálogo e o cálculo.
- **Estados:** `pending`, `processing`, `analyzed`, `failed`, `confirmed`, com nova tentativa.
- **Sem comida ou ilegível:** mensagem clara, sem números.
- **Apresentação:** faixa de calorias e macronutrientes, medida caseira e confiança, em cor neutra.
- **Confirmação** com uma ação, e **correção** que preserva a estimativa original.
- **Catálogo:** origem, versão e licença por item; busca; composições próprias identificadas como tal.
- **Custo:** registro por análise; limite por usuário; alerta de gasto total.
- **Avaliação:** dataset versionado e script reprodutível, com comparação de ao menos dois candidatos de provedor.

## Dependências

- **Fase 02** concluída: autenticação, consentimentos, exclusão e isolamento comprovados.
- **Ação do responsável:** pedido à TBCA, de preferência antes desta fase, e chaves do provedor de IA.
- **Fontes a consultar de novo:** preços e política de dados dos provedores; OpenAI, ainda não verificado; TBCA, USDA, Open Food Facts e a licença da TACO.

## Arquivos e módulos esperados

```text
apps/api/app/domains/nutrition/
apps/api/app/domains/food_ai/
apps/api/app/domains/food_ai/adapters/      Um por provedor
apps/api/app/domains/food_catalog/
apps/api/app/domains/food_catalog/adapters/ Um por base
apps/api/config/prompts/                    Prompts versionados
apps/api/db/migrate/                        food_entries, food_items, food_analysis_results, ai_usage_records, prompt_versions, food_catalog, food_compositions
apps/mobile/src/features/meals/
evaluation/                                 Dataset e script, conforme a licença das imagens
```

## Critérios de aceite

- `AC-03-01` (FR-FOOD-001, FR-FOOD-002, NFR-SEC-002): a foto é enviada por URL assinada de no máximo 15 minutos, é validada, o EXIF é removido do objeto guardado, e o objeto não pode ser lido sem assinatura. **Comprovado por:** testes com imagem com GPS e tentativa real de acesso.
- `AC-03-02` (FR-FOOD-003, FR-FOOD-004, FR-FOOD-005, FR-FOOD-006, NFR-SAFETY-001): uma foto real percorre todo o pipeline em ambiente de teste, com provedor real, e produz itens, porções, faixas e confiança. **Comprovado por:** demonstração registrada e teste de integração com dublê.
- `AC-03-03` (FR-FOOD-006, FR-CATALOG-001): cada item calculado traz a origem do dado nutricional, e o modelo nunca é a fonte das calorias. **Comprovado por:** teste do cálculo e revisão do schema.
- `AC-03-04` (FR-FOOD-007, FR-FOOD-008): confirmar exige uma ação; corrigir recalcula e preserva a estimativa original. **Comprovado por:** testes e demonstração no app.
- `AC-03-05` (FR-FOOD-009, FR-FOOD-010, NFR-PERF-003): histórico paginado, sem N+1; apagar refeição remove a foto e o `raw_response` da análise. **Comprovado por:** testes, incluindo contagem de consultas.
- `AC-03-06` (FR-FOOD-011, FR-FOOD-012): foto sem comida ou ilegível não gera números e é apagada automaticamente, e o registro manual funciona. **Comprovado por:** testes e dataset.
- `AC-03-07` (FR-FOOD-013, FR-FOOD-014): trocar de provedor exige só adaptador e configuração, sem mudar Nutrition; cada análise registra prompt, modelo, resposta e custo. **Comprovado por:** dois adaptadores reais funcionando, usados na comparação de provedores, e verificação de limites de domínio.
- `AC-03-08` (FR-FOOD-015): o dataset roda de forma reprodutível, e as metas de qualidade foram definidas e registradas após a primeira medição. **Comprovado por:** relatório de avaliação com data.
- `AC-03-09` (FR-CATALOG-002, FR-CATALOG-003, FR-CATALOG-004): pratos brasileiros compostos podem ser buscados e identificados como composição própria; nada é carregado sem licença na ADR 0007. **Comprovado por:** testes e leitura da ADR.
- `AC-03-10` (NFR-PRIVACY-001, NFR-PRIVACY-005): sem o consentimento vigente para o operador e a região atuais, nenhuma imagem sai do sistema; o conteúdo enviado ao adaptador não traz EXIF, nome ou e-mail; o provedor escolhido tem política documentada de não treinar com as entradas, relida por inteiro, incluindo retenção. **Comprovado por:** testes, inspeção do conteúdo enviado ao adaptador e registro de fontes atualizado.
- `AC-03-11` (NFR-PRIVACY-004): logs e relatórios de erro de uma análise, com sucesso ou falha, não contêm URLs assinadas, itens, valores ou a saída do modelo. **Comprovado por:** teste sobre os logs, incluindo `InvalidOutputError`, e sobre os registros dos clientes.
- `AC-03-12` (NFR-COST-001, NFR-COST-002, NFR-COST-003): o custo pode ser agregado por usuário; o limite responde `429` com mensagem clara; o alerta dispara. **Comprovado por:** testes e demonstração.
- `AC-03-13` (NFR-SAFETY-002, NFR-SAFETY-003, NFR-SAFETY-004): não há meta, limite ou cor de alerta em calorias, nem conselho de saúde no texto gerado, e os textos estáticos passam por uma verificação automática contra a lista de linguagem. **Comprovado por:** teste de contrato, verificação dos textos, revisão das telas e dataset com tentativa de instrução na imagem.
- `AC-03-14` (NFR-PERF-002): a análise tem p95 de até 60 segundos no dataset. **Comprovado por:** relatório de avaliação. Mudar a meta exige decisão do responsável, registrada antes do encerramento.
- `AC-03-15` (FR-MOBILE-001, FR-MOBILE-002): as telas de câmera, resultado e histórico tratam permissão negada, falha de rede e os três estados. **Comprovado por:** testes de componente e demonstração.
- `AC-03-16`: ADRs 0006 e 0007 decididas antes do encerramento. **Comprovado por:** leitura das ADRs.
- `AC-03-17`: o prazo máximo das fotos está decidido, aplicado por rotina, e o app apaga cópias locais ao concluir o envio, ao sair e ao excluir a conta. **Comprovado por:** teste da rotina e dos estados do app, com o prazo em [DATABASE_DESIGN.md](../../architecture/DATABASE_DESIGN.md).

## Testes

- Calculadora: faixas ordenadas, somas, item desconhecido, soma parcial.
- Validação de saída: fora do schema, valores absurdos, campos a mais.
- Falhas do provedor, com classificação e tentativas.
- Idempotência do job: reentrega não paga outra chamada.
- Concorrência em `client_request_id`.
- Revogação de consentimento durante a análise.
- Exclusão de conta alcança refeições, itens e fotos.
- Texto na imagem não muda o comportamento.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Estimativa ruim em pratos brasileiros | Perda de confiança | Composições próprias, faixas, correção, dataset focado |
| TBCA indisponível | Qualidade menor | Caminho sem TBCA definido; pedido com antecedência |
| Faixas muito largas ou estreitas | Inúteis ou enganosas | Medir a proporção de acerto das faixas no dataset |
| Custo por foto maior que o esperado | Inviabilidade | Medir, reduzir imagem, comparar modelos, limitar uso |
| Instrução maliciosa em imagem | Saída manipulada | Schema estrito, sem ferramentas, teste no dataset |
| Provedor muda política | Problema legal | Registro de fontes, abstração de provedor |

## Entregáveis

Pipeline completo, telas móveis, catálogo inicial, dataset e relatório de avaliação, ADRs decididas, registro de fontes atualizado, relatório da fase.

## Definition of Done

[DEFINITION_OF_DONE.md](../../engineering/DEFINITION_OF_DONE.md), mais: ADR 0007 aceita; prova real com o provedor registrada, além dos testes com dublê.

## Estratégia de revisão

`software-architect` (separação de ver e calcular), `backend-reviewer` (jobs, idempotência), `security-reviewer` (fotos, consentimento, transferência), `frontend-mobile-reviewer` (incerteza, estados), `qa-reviewer` (dataset, critérios). O responsável aprova a escolha do provedor, as metas de qualidade e o relatório.
