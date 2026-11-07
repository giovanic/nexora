# 0012 — Opções de monetização

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-COST-001, NFR-COST-002

## Contexto

O responsável considera monetizar de forma eficaz parte da definição de sucesso, mas não escolheu um modelo. O produto tem custo variável por foto analisada: da ordem de US$ 0,001 a US$ 0,013 por foto, conforme o modelo, em estimativa a medir ([AI_ARCHITECTURE.md](../AI_ARCHITECTURE.md)). O termo do Strava não traz proibição própria de uso comercial no texto lido, mas prevê possível cobrança pela API. Lojas de aplicativos podem exigir o próprio sistema de pagamento, o que não foi verificado.

## Problema

Como validar quanto e por que as pessoas pagariam, sem comprometer os princípios do produto nem construir cobrança cedo demais?

## Alternativas

1. **Freemium por volume de análises:** gratuito com limite; assinatura com análises ilimitadas ou maiores. O custo acompanha a receita.
2. **Assinatura com recursos avançados:** relatórios, planejamento e missões avançadas são pagos. Risco de esconder o que dá retenção.
3. **Teste gratuito e depois assinatura:** simples, com mais atrito inicial.
4. **Parcerias com assessorias, academias ou nutricionistas:** receita B2B. Exige outro tipo de venda, e compartilhar dados precisa de consentimento específico.
5. **Publicidade:** incompatível com a confiança em dados de saúde. **Rejeitada em princípio.**
6. **Venda de dados:** **proibida.**

## Decisão

**Já vale, para qualquer modelo:**

- Não vender dados de saúde.
- Não cobrar por exportação ou exclusão de dados.
- Não colocar proteções de segurança atrás de pagamento.
- Sem cobrança nas fases atuais do roadmap.
- Custo de IA medido desde a Fase 03.

**Fica para depois do M1:** escolher o modelo.

**Como validar:**

1. Medir o custo real por usuário ativo no beta.
2. Perguntar às pessoas do beta o que pagariam, e por quê.
3. Testar a disposição a pagar com uma oferta real ou lista de interesse antes de implementar cobrança.
4. Verificar regras de pagamento das lojas de aplicativos.

**Hipótese inicial:** alternativa 1, porque o custo variável acompanha o valor recebido.

## Justificativa

Construir cobrança antes de ter uso real é desperdício para uma só pessoa. Os limites protegem a confiança, que é essencial em dados de saúde.

## Consequências

- O limite de análises já existe desde a Fase 03, e pode virar parte do modelo.
- Uma fase de cobrança será proposta depois do M1, se fizer sentido.

## Estado da decisão

Proposta
