# 0007 — Bases de dados nutricionais

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-CATALOG-001, FR-CATALOG-002, FR-CATALOG-004, FR-FOOD-006

## Contexto

O público é brasileiro, e pratos como feijoada e arroz com feijão precisam de boa cobertura. O produto pretende ser comercial. Consulta de 2026-11-05 ([fontes](../EXTERNAL_SOURCES.md)):

- **TBCA 7.3:** a melhor cobertura brasileira, mas o texto diz *"Para fins comerciais, é necessário contatar os coordenadores"*, *"Não é permitida a reprodução total ou parcial do material"* e *"Não é permitida a comercialização"*. Sem API ou download em massa encontrado.
- **USDA FoodData Central:** CC0, com API e download, fraca em pratos brasileiros.
- **Open Food Facts:** ODbL, produtos embalados, com atribuição e compartilhamento pela mesma licença. O alcance disso em um SaaS é questão jurídica em aberto.
- **TACO:** licença não verificada.

## Problema

De quais bases o produto pode usar dados legalmente e com qualidade suficiente para o público brasileiro?

## Alternativas

1. **Só USDA:** livre, mas pobre em pratos locais.
2. **USDA mais composições próprias de pratos brasileiros:** livre, e melhora a cobertura. Exige escrever e revisar receitas-base. Estimativa menos precisa que dado analítico.
3. **TBCA autorizada:** melhor qualidade, depende de resposta dos coordenadores, e possivelmente de condições comerciais.
4. **Open Food Facts para embalados:** cobre outro caso, com incerteza jurídica.
5. **Base comercial paga:** não avaliada.

## Decisão

**Decisão do responsável em 2026-11-13, a aceitar depois da leitura do relatório da Fase 03:**

- **M1:** alternativa 2, USDA FoodData Central mais composições próprias de pratos brasileiros.
  - Bases e versões usadas, conforme o [registro de fontes](../EXTERNAL_SOURCES.md): *Foundation Foods* 2026-10-29 e *SR Legacy* 2018-04, com licença `CC0-1.0`. As composições próprias têm versão `2026-11` e licença `project-owned`, com `review: pending_nutritionist`.
  - Subconjunto curado e versionado em `apps/api/db/catalog/usda_fdc.yml` e `apps/api/db/catalog/compositions.yml`.
- **TACO depois**, por adaptador, só após a resposta do NEPA/UNICAMP a `taco@unicamp.br`. O texto da 4ª edição (2011) permite reprodução com citação da fonte e não menciona uso comercial, alteração nem base derivada, e o enquadramento em SaaS é questão jurídica (registro de fontes). Até a resposta, a TACO não entra.
- **TBCA bloqueada**: o texto de uso proíbe reprodução e comercialização sem os coordenadores. Só entra com autorização por escrito.
- **Open Food Facts fora do M1**: a cláusula share-alike da ODbL num SaaS é questão jurídica sem parecer.
- **Revisão das receitas por nutricionista antes do beta.** Enquanto não acontecer, as composições ficam marcadas `pending_nutritionist` e a interface as identifica como composição própria.

**Regras que já valem:** nenhuma base entra sem licença verificada, registrada aqui (FR-CATALOG-004). Toda base fica atrás de um adaptador, com origem, versão e licença por item.

**Evidência no código (Fase 03):**

- `FoodCatalog::LoadCatalog` (`apps/api/app/domains/food_catalog/services/load_catalog.rb`) só carrega fontes em `ALLOWED_SOURCES = %w[usda_fdc project]`, recusa arquivo sem licença (`MissingLicense`), fonte fora da lista (`UnknownSource`) e prato cujas partes não somam 100 g (`InvalidComposition`). É idempotente.
- `apps/api/spec/domains/food_catalog/load_catalog_spec.rb` cobre essas recusas, a carga repetida sem duplicar, "no TACO or TBCA source exists in the data files", licença, citação e versão em todo registro USDA, e a carga dos arquivos reais.

**A Fase 03 não pode ser concluída** sem esta ADR passar a `Aceita`. Aceita em 2026-11-17 (ver "Estado da decisão").

## Justificativa

Usar a TBCA sem autorização expõe o produto a risco jurídico. Composições próprias sobre uma base CC0 são um caminho legal que não depende de terceiros, ainda que menos preciso, e a incerteza aparece nas faixas.

## Consequências

- **Ação do responsável:** escrever para `taco@unicamp.br` (NEPA/UNICAMP) para a TACO entrar depois do M1. A TBCA (`tbca.contato@usp.br`) só se o responsável decidir retomá-la.
- Receitas-base viram conteúdo mantido pelo projeto, e precisam de revisão por alguém qualificado em nutrição antes do beta, se possível.
- A interface identifica pratos como composição própria.
- O dataset de avaliação mede o efeito dessa escolha.

## Estado da decisão

Aceita

**Aceita em 2026-11-17** pelo responsável, depois de ler o relatório da Fase 03 ("aprovo", em resposta à proposta de aprovar a fase e aceitar as ADRs 0007 e 0019). Vale a decisão de 2026-11-13: USDA FoodData Central e composições próprias; TACO aguardando a resposta do NEPA, por nova revisão desta ADR; TBCA bloqueada.
