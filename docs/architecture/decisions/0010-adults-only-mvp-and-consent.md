# 0010 — MVP só para adultos e consentimento

- **Data:** 2026-11-05
- **Requisitos relacionados:** FR-ID-001, FR-ID-007, FR-ID-008, NFR-PRIVACY-001, NFR-SAFETY-005

## Contexto

A LGPD ([fontes](../EXTERNAL_SOURCES.md)) trata dado referente à saúde como sensível (art. 5, II). Fotos de refeições e atividades podem revelar esse tipo de dado (art. 11, §1). O consentimento deve ser específico e destacado (art. 11, I), autorizações genéricas são nulas (art. 8, §4), e a revogação deve ser facilitada (art. 8, §5). O tratamento de dados de crianças e adolescentes segue o melhor interesse (art. 14). O Master Prompt pede prioridade a adultos e um modo específico, caso haja suporte a adolescentes.

## Problema

Quem pode usar o produto no MVP, e como o consentimento funciona no produto?

## Alternativas

**Público:**

1. **Só adultos no MVP:** menos público, menos risco, sem um modo especial agora.
2. **Adultos e adolescentes, com modo específico:** mais público, muito mais trabalho e risco desde o início.

**Consentimento:**

1. **Consentimento único no cadastro:** simples, mas genérico e possivelmente nulo.
2. **Consentimento por finalidade:** mais telas, mais robusto.

## Decisão

- MVP **só para pessoas com 18 anos ou mais**. A conta exige a confirmação, e `users.adult_confirmed_at` é obrigatório no banco.
- **Consentimento por finalidade**, versionado, com histórico, para: tratamento de dados de saúde, análise de fotos por IA (incluindo transferência internacional quando existir), integração com o Strava e métricas de uso.
- Revogar é tão fácil quanto consentir, e o produto continua funcionando no que não depender daquela finalidade.
- Dados de saúde são tratados como sensíveis, mesmo quando a classificação seria discutível.
- A base legal de cada operação e a da transferência internacional **não são decididas aqui**: são propostas em [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md), a confirmar na revisão jurídica do M1.
- Suporte a menores exige uma nova ADR e o modo descrito em [HEALTH_DATA_SAFETY.md](../../security/HEALTH_DATA_SAFETY.md).

## Justificativa

Reduz o risco no início e ainda atende ao público principal. O consentimento por finalidade é a leitura de engenharia do texto da lei. **Isto não é parecer jurídico.**

## Consequências

- A confirmação de maioridade é declaratória. Fica registrada a limitação, e se avaliará se é suficiente na revisão jurídica.
- Exige textos claros e versionados.
- Exclui deliberadamente menores de idade.

## Nota de 2026-11-13

O responsável decidiu que revogar `health_data` apaga os dados de saúde do perfil (esportes e níveis, motivações e nome de exibição) e mantém a conta, que volta à tela de consentimento. Fuso horário e unidades ficam, por serem dados técnicos. Isso mantém a implementação coerente com "revogar é tão fácil quanto consentir". O destino desses dados vai à revisão jurídica. Esta nota não muda o estado da decisão.

## Estado da decisão

Aceita
