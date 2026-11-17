# 0019 — Armazenamento de fotos e processamento de imagem

- **Data:** 2026-11-13
- **Requisitos relacionados:** FR-FOOD-001, FR-FOOD-002, NFR-SEC-001, NFR-PRIVACY-002

## Contexto

A Fase 03 recebe fotos de refeições, que são dados sensíveis (LGPD). A foto precisa ficar em armazenamento privado, chegar ao armazenamento sem passar pela API, perder os metadados (EXIF) antes de ir à IA e ser apagada 30 dias após a análise. Os fatos externos (URL pré-assinada, licenças e versões do armazenamento, gems) estão no [registro de fontes](../EXTERNAL_SOURCES.md), seção "Fase 03: armazenamento, imagem e câmera". A fonte da AWS não oferece limite de tamanho nem de tipo para PUT pré-assinado, e as condições de POST policy não foram verificadas. O MinIO está arquivado. A biblioteca libvips (`libvips42` 8.12.1) foi instalada na máquina de desenvolvimento no início da Tarefa 2.

## Problema

Onde guardar as fotos, como autorizar o envio com limite de tipo e de tamanho, e com que ferramenta normalizar a imagem antes da IA?

## Alternativas

1. **Disco local ou Active Storage no disco.** Simples, mas não serve à produção, mistura foto com a aplicação e não dá URL assinada de prazo curto.
2. **S3 compatível por adaptador, com URL pré-assinada de PUT.** O app envia direto ao armazenamento. A API só autoriza e valida depois. Custo: um serviço a mais no desenvolvimento e a prova de que o PUT assinado respeita tipo e tamanho.
3. **Envio pela API (multipart).** Dá controle total do tamanho, mas a foto passa pela memória da API e ocupa o processo web.
4. **Armazenamento local compatível com S3:** SeaweedFS 4.53 (Apache-2.0, ativo), RustFS 1.0.5 (Apache-2.0, ativo), MinIO (arquivado, AGPL-3.0, descartado) e Garage (licença e versão não verificadas).
5. **Normalização:** `libvips` por `ruby-vips` (com ou sem `image_processing`), ou ImageMagick. A libvips é descrita pelo projeto como orientada à demanda e de baixo uso de memória, e tem licença LGPL-2.1-or-later (a gem `ruby-vips` é MIT). A ligação é dinâmica, por ffi.

## Decisão

O que já vale como direção, validado na primeira tarefa de código da Fase 03 (o estado da ADR está no fim):

- Armazenamento **S3 compatível atrás do adaptador** `FoodAi::Adapters::ObjectStorage` (instância configurada em `FoodAi.storage`; a foto é do Food AI, que consulta o consentimento), sobre `aws-sdk-s3`. Bucket privado, leitura só por URL assinada de até 15 minutos.
- **SeaweedFS no desenvolvimento**, só em loopback. A tarefa prova por execução: PUT pré-assinado, recusa de `Content-Length` diferente do assinado, GET sem assinatura recusado e expiração. **RustFS** é a alternativa se o SeaweedFS falhar em algum ponto.
- **URL pré-assinada de PUT que assina `Content-Type` e `Content-Length`**, com validade de 15 minutos. Como a fonte não confirma esse comportamento, a prova por execução é obrigatória, e o tamanho e o tipo reais são conferidos de novo no job, pelos bytes (`marcel`, declarado no `Gemfile` como `marcel ~> 1.1`; antes só vinha como dependência transitiva).
- **libvips** (só `ruby-vips`, sem `image_processing`) normaliza a imagem: recusa acima de 40 megapixels, aplica a orientação, remove todos os metadados, reduz o lado maior para 1.568 px e regrava em JPEG. Imagem com perfil ICC embutido é convertida para sRGB antes de o perfil ser removido, para as cores não mudarem; se a conversão falhar, o perfil é só descartado. WebP animado ou de várias páginas usa só o primeiro quadro, substituindo o objeto guardado.
- A chave do objeto é aleatória (`food-photos/<uuid>`) e fica em `food_photos.object_key`, que é dona do ciclo de vida da foto ([DATABASE_DESIGN.md](../DATABASE_DESIGN.md)). A retenção é de 30 dias após a análise.
- Fica por decidir o armazenamento de produção, que acompanha a [ADR 0015](0015-hosting-and-deployment.md). O adaptador isola essa escolha.

## Justificativa

O envio direto ao armazenamento mantém a API fora do caminho dos bytes. O adaptador S3 serve a qualquer provedor e a qualquer alternativa local. SeaweedFS e RustFS têm licença permissiva e estão ativos, ao contrário do MinIO. A libvips é a escolha usual com Rails e, segundo o projeto, usa pouca memória (fonte no registro). As gems novas são justificadas aqui: `aws-sdk-s3` (abaixo) e `ruby-vips`, binding oficial da libvips, que abre a imagem de forma preguiçosa e lê largura e altura do cabeçalho antes de decodificar, o que sustenta a recusa acima de 40 megapixels. A gem `image_processing` não é usada: ela trabalha com arquivos temporários, e a foto não deve ir ao disco; a Tarefa 2 chama `ruby-vips` direto, em memória. **Pendência jurídica para o responsável:** a LGPL-2.1-or-later da libvips em SaaS (ligação dinâmica, sem modificação) não tem parecer jurídico. Está também na lista de pendências de [PRIVACY_AND_LGPD.md](../../security/PRIVACY_AND_LGPD.md).

## Consequências

- Mais fácil: foto privada com acesso de prazo curto, sem passar pela API; troca de armazenamento sem mexer em Nutrition.
- Mais difícil: um serviço novo no `docker-compose.yml`; dependência nativa da libvips na máquina (`sudo apt install libvips42`) e no CI (`libvips42t64`, nome no `ubuntu-24.04`); specs `:object_storage` falam com o SeaweedFS local.
- Feito: prova do PUT assinado (seção abaixo). A promoção a `Aceita` cabe ao responsável, depois de ler o relatório da fase.

## Evidência da Tarefa 1 (2026-11-13)

Prova por execução contra o SeaweedFS `chrislusf/seaweedfs:4.53` local (`apps/api/spec/integration/object_storage_spec.rb`, tag `:object_storage`). Os seis pontos passaram no SeaweedFS, então o RustFS não foi necessário:

- PUT pré-assinado com tipo e tamanho assinados grava o objeto;
- PUT com `Content-Length` diferente do assinado é recusado;
- PUT com outro `Content-Type` é recusado;
- GET sem assinatura é recusado;
- URL expirada (`expires_in: 1`, espera de 2 s) é recusada;
- `expires_in` acima de 900 levanta `ArgumentError`.

Achado: o `Aws::S3::Presigner` **não assina `content-length`** por padrão (lista de cabeçalhos ignorados, "due to a ELB bug"), e sem isso o armazenamento aceitou um corpo de outro tamanho. O adaptador passa `whitelist_headers: ["content-length"]`, e só então a recusa passou a valer. O tamanho real continua conferido de novo no job.

Justificativa da gem `aws-sdk-s3` (~> 1.242, Apache-2.0): é o cliente S3 oficial, faz a assinatura SigV4 e a URL pré-assinada, e serve a qualquer armazenamento S3 compatível. Fazer a assinatura à mão seria código de segurança próprio, mais arriscado. Fica atrás do adaptador `FoodAi::Adapters::ObjectStorage`.

**Decisão do responsável em 2026-11-14: HEIC e HEIF aceitos e convertidos para JPEG no backend.** A libvips normaliza `image/heic` e `image/heif` como os demais tipos, e a saída é sempre JPEG. O app deixa de recusar HEIC antes do envio. No CI, o pacote `libheif-plugin-libde265` acompanha a `libvips42t64` para decodificar HEVC (fonte e data em `EXTERNAL_SOURCES.md`). Evidência: `apps/api/spec/domains/food_ai/normalize_photo_spec.rb` e `apps/api/spec/requests/food_entry_uploads_spec.rb` (normalização e aceite de HEIC/HEIF; o spec de HEIC é pulado se a libvips local não grava HEIC) e o passo `libheif-plugin-libde265` em `.github/workflows/ci.yml`.

## Prova por execução dos seis pontos

Os seis pontos da Tarefa 1 estão em `apps/api/spec/integration/object_storage_spec.rb` (tag `:object_storage`, SeaweedFS real, `docker compose up -d seaweedfs`): PUT assinado grava, `Content-Length` diferente é recusado, outro `Content-Type` é recusado, GET sem assinatura é recusado, URL expirada é recusada e `expires_in` acima de 900 levanta erro.

## Estado da decisão

Aceita

**Aceita em 2026-11-17** pelo responsável, depois de ler o relatório da Fase 03 ("aprovo", em resposta à proposta de aprovar a fase e aceitar as ADRs 0007 e 0019). Com a evidência acima e a decisão de HEIC e HEIF de 2026-11-14. A pendência jurídica da LGPL-2.1 da libvips num SaaS continua aberta em `PRIVACY_AND_LGPD.md`. O armazenamento de produção é escolhido no M1 (ADR 0015).
