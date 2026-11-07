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

**Já vale:** nenhuma base entra sem licença verificada, registrada aqui (FR-CATALOG-004). TBCA e TACO estão **bloqueadas** até que isso aconteça. Toda base fica atrás de um adaptador, com origem, versão e licença por item.

**Proposta a validar na Fase 03:** alternativa 2 para o M1, com a TBCA substituindo ou complementando se a autorização chegar.

**A Fase 03 não pode ser concluída** sem esta ADR passar a `Aceita`, com as bases escolhidas.

## Justificativa

Usar a TBCA sem autorização expõe o produto a risco jurídico. Composições próprias sobre uma base CC0 são um caminho legal que não depende de terceiros, ainda que menos preciso, e a incerteza aparece nas faixas.

## Consequências

- **Ação do responsável:** escrever para `tbca.contato@usp.br` antes da Fase 03.
- Receitas-base viram conteúdo mantido pelo projeto, e precisam de revisão por alguém qualificado em nutrição antes do beta, se possível.
- A interface identifica pratos como composição própria.
- O dataset de avaliação mede o efeito dessa escolha.

## Estado da decisão

Proposta
