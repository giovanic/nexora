# 0014 — Ferramentas de contrato da API

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-OPS-002

## Contexto

Mobile e web consomem a mesma API, e o Master Prompt pede REST com OpenAPI. A versão atual da especificação é a 3.2.1. O README do `rswag` declara compatibilidade com OpenAPI 3.0 e busca mantenedores ([fontes](../EXTERNAL_SOURCES.md)). Outras ferramentas não foram avaliadas.

## Problema

Como manter o contrato verdadeiro, sem retrabalho, e como os clientes obtêm os tipos?

## Alternativas

**Fonte da verdade:**

1. **Contrato primeiro:** arquivo OpenAPI versionado; o backend é validado contra ele em teste.
2. **Gerado dos testes (`rswag`):** documentação sai dos testes. Limitado à versão de OpenAPI suportada, e com manutenção incerta.
3. **Gerado de anotações no código:** próximo ao código, mas com dependência adicional.

**Tipos dos clientes:** gerar TypeScript a partir do contrato, em `packages/contracts`, ou escrever à mão. Escrever à mão duplica o contrato.

## Decisão

**Já vale:** existe um contrato OpenAPI, verificado no CI contra a implementação. Os tipos dos clientes vêm dele, sem duplicação manual.

**Fica para a Fase 01:** a ferramenta e a versão de OpenAPI. Critério: validar uma requisição e resposta reais no CI, gerar tipos para web e mobile, e ter manutenção ativa, confirmada na fonte.

**Proposta a validar:** alternativa 1.

## Justificativa

Contrato primeiro independe de uma biblioteca específica, e funciona bem com vários clientes. A confirmação depende de um teste real.

## Consequências

- `packages/contracts` é justificado se a geração de tipos for adotada.
- Cada fase atualiza o contrato antes dos clientes.

## Estado da decisão

Proposta
