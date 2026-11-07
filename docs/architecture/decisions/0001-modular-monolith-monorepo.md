# 0001 — Monólito modular em monorepo

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-OPS-001, NFR-OPS-002

## Contexto

O produto tem um único desenvolvedor, 12 domínios e dois clientes. O responsável declarou preferência por um monólito modular e pediu para evitar microsserviços prematuros. Backend, web e mobile evoluem juntos, e o contrato de API precisa ficar consistente entre eles.

## Problema

Como organizar código e implantação de forma a manter os domínios separados sem criar um custo operacional que uma só pessoa não consiga sustentar?

## Alternativas

1. **Monólito modular em monorepo:** um deploy de backend, domínios por namespace, um repositório para tudo.
   - A favor: simples de operar; mudança ponta a ponta em um só commit; transações locais.
   - Contra: exige disciplina para manter os limites; um só deploy para tudo.
2. **Microsserviços:**
   - A favor: escala e deploy independentes.
   - Contra: rede, consistência distribuída e observabilidade para uma só pessoa manter, sem necessidade real hoje.
3. **Monólito com repositórios separados por cliente:**
   - A favor: pipelines isolados.
   - Contra: mudanças de contrato atravessam repositórios, e o harness se fragmenta.

## Decisão

Monólito modular em Rails e monorepo com `apps/api`, `apps/web`, `apps/mobile` e, se justificado, `packages/contracts`.

## Justificativa

Atende à preferência do responsável e minimiza a carga operacional. A separação vem de limites verificáveis, não de rede. Um domínio pode ser extraído no futuro, já que se comunica por API pública e eventos.

## Consequências

- Um único pipeline de CI cobre tudo, com etapas por aplicação.
- Os limites dependem da [ADR 0003](0003-domain-boundaries-without-engines.md).
- Extrair um serviço exigirá uma nova ADR com evidência de necessidade.

## Estado da decisão

Aceita
