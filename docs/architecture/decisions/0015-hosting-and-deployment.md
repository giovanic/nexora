# 0015 — Hospedagem e deploy

- **Data:** 2026-11-05
- **Requisitos relacionados:** NFR-OPS-003, NFR-OPS-004, NFR-PRIVACY-001

## Contexto

O [beta fechado](../../roadmap/phases/MILESTONE_M1_CLOSED_BETA.md) exige um ambiente real, antes da Fase 09. O responsável opera tudo sozinho, então a carga operacional é prioridade. Há dados sensíveis, e a localização dos dados pode exigir base de transferência internacional (LGPD, art. 33). Nenhuma oferta de hospedagem foi avaliada nesta fase.

## Problema

Onde rodar API, banco, Redis, jobs e armazenamento com a menor carga operacional, custo compatível e privacidade adequada?

## Alternativas

A avaliar no M1, consultando preços e localização atuais:

1. **Plataforma gerenciada (PaaS):** pouca operação, custo maior por recurso.
2. **VPS com deploy em container:** barato, mas backups, atualizações e monitoramento ficam com o responsável.
3. **Serviços gerenciados em nuvem grande:** região no Brasil possível, com complexidade maior.

**Mobile:** distribuição interna pelas lojas de teste. O uso de EAS é avaliado na mesma época.

## Decisão

**Já vale, para qualquer alternativa:** banco com backup automático e restauração testada; armazenamento privado; segredos fora do repositório; deploy reproduzível com caminho de reversão; dados em repouso cifrados.

**Fica para o M1:** o provedor. Critérios: operação por uma só pessoa, custo no volume do beta, região e base de transferência, backups e rota de crescimento.

## Justificativa

O conhecimento necessário (preço e região) muda, e só importa perto do uso. Decidir agora seria hipotético.

## Consequências

- A Fase 09 reavalia a escolha para a escala de lançamento.
- O M1 atualiza esta ADR e os documentos de operação.

## Estado da decisão

Proposta
