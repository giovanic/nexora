# 0014 — Ferramentas de contrato da API

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-OPS-002

## Contexto

Mobile e web consomem a mesma API, e o Master Prompt pede REST com OpenAPI. A versão atual da especificação é a 3.2.1. O README do `rswag` declara compatibilidade com OpenAPI 3.0 e busca mantenedores ([fontes](../EXTERNAL_SOURCES.md)). As alternativas avaliadas estão em Decisão.

## Problema

Como manter o contrato verdadeiro, sem retrabalho, e como os clientes obtêm os tipos?

## Alternativas

**Fonte da verdade:**

1. **Contrato primeiro:** arquivo OpenAPI versionado; o backend é validado contra ele em teste.
2. **Gerado dos testes (`rswag`):** documentação sai dos testes. Limitado à versão de OpenAPI suportada, e com manutenção incerta.
3. **Gerado de anotações no código:** próximo ao código, mas com dependência adicional.

**Tipos dos clientes:** gerar TypeScript a partir do contrato, em `packages/contracts`, ou escrever à mão. Escrever à mão duplica o contrato.

## Decisão

**Alternativa 1, contrato primeiro,** em `packages/contracts/openapi.yaml`, escrito em **OpenAPI 3.1.1**. Os tipos dos clientes vêm dele, sem duplicação manual, e ficam versionados em `packages/contracts/generated/api.d.ts`.

| Função | Ferramenta | Manutenção, confirmada em 2026-11-06 |
|---|---|---|
| Validar respostas reais nos request specs | `openapi_first` 4.3, só em teste | Release de 2026-11-03 |
| Gerar tipos | `openapi-typescript` 7.13, com TypeScript 5.9 isolado em `packages/contracts` | Release de 2026-02-11 |

Por que não a 3.2.1, a mais recente: `openapi_first`, `committee` e `openapi-typescript` declaram suporte só a 3.0 e 3.1.

Por que `openapi_first`, e não `committee`: foi feito para teste de contrato e não declara as restrições de JSON Schema que o `committee` lista para 3.x.

O teste de rotas compara pares de método e caminho das rotas públicas do Rails com as operações do contrato, nos dois sentidos, convertendo `:id` em `{id}`, porque a validação de resposta só alcança o que os testes exercitam.

## Evidência

Execução de 2026-11-06:

| Verificação | Resultado |
|---|---|
| Mudar `status` de `unavailable` para `degraded` no contrato | `health_ready_spec` falha; restaurado, passa |
| Erro 500 validado contra o esquema `Error` | Passa |
| Rotas públicas contra operações do contrato, por método e caminho (`spec/contract/routes_spec.rb`) | Passa nos dois sentidos |
| `npm run generate -w @app/contracts` | Tipos gerados |
| Alterar `generated/api.d.ts` e rodar `npm run check -w @app/contracts` | Falha; regenerado, passa |

## Justificativa

Contrato primeiro independe de uma biblioteca específica, e funciona bem com vários clientes. Os testes acima confirmaram que a validação reprova divergência real.

## Consequências

- `packages/contracts` se justifica pela geração de tipos.
- Cada fase atualiza o contrato antes dos clientes.
- **Risco:** a última release do `openapi-typescript` tem 9 meses, e ele declara `typescript` `^5.x`. O custo de troca é baixo, porque ele só gera um arquivo.
- **Limite:** a validação cobre respostas exercitadas em request specs que chamam `expect_response_to_match_contract`. Cabe a cada fase chamá-la nas rotas novas.
- Rotas `/internal` ficam fora do contrato, porque não existem em produção.

## Estado da decisão

Aceita
