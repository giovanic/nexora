# 0019 — Armazenamento de fotos e processamento de imagem

- **Data:** 2026-11-13
- **Requisitos relacionados:** FR-FOOD-001, FR-FOOD-002, NFR-SEC-001, NFR-PRIVACY-002

## Contexto

A Fase 03 recebe fotos de refeições, que são dados sensíveis (LGPD). A foto precisa ficar em armazenamento privado, chegar ao armazenamento sem passar pela API, perder os metadados (EXIF) antes de ir à IA e ser apagada 30 dias após a análise. Os fatos externos (URL pré-assinada, licenças e versões do armazenamento, gems) estão no [registro de fontes](../EXTERNAL_SOURCES.md), seção "Fase 03: armazenamento, imagem e câmera". A fonte da AWS não oferece limite de tamanho nem de tipo para PUT pré-assinado, e as condições de POST policy não foram verificadas. O MinIO está arquivado. A máquina de desenvolvimento ainda não tem a biblioteca libvips.

## Problema

Onde guardar as fotos, como autorizar o envio com limite de tipo e de tamanho, e com que ferramenta normalizar a imagem antes da IA?

## Alternativas

1. **Disco local ou Active Storage no disco.** Simples, mas não serve à produção, mistura foto com a aplicação e não dá URL assinada de prazo curto.
2. **S3 compatível por adaptador, com URL pré-assinada de PUT.** O app envia direto ao armazenamento. A API só autoriza e valida depois. Custo: um serviço a mais no desenvolvimento e a prova de que o PUT assinado respeita tipo e tamanho.
3. **Envio pela API (multipart).** Dá controle total do tamanho, mas a foto passa pela memória da API e ocupa o processo web.
4. **Armazenamento local compatível com S3:** SeaweedFS 4.53 (Apache-2.0, ativo), RustFS 1.0.5 (Apache-2.0, ativo), MinIO (arquivado, AGPL-3.0, descartado) e Garage (licença e versão não verificadas).
5. **Normalização:** `libvips` por `ruby-vips` e `image_processing`, ou ImageMagick. A libvips decodifica por partes, com menos memória, e a pilha tem licença MIT.

## Decisão

Em estado `Proposta`. O que já vale como direção, validado na primeira tarefa de código da Fase 03:

- Armazenamento **S3 compatível atrás do adaptador** `FoodAi::Adapters::ObjectStorage` (instância configurada em `FoodAi.storage`; a foto é do Food AI, que consulta o consentimento), sobre `aws-sdk-s3`. Bucket privado, leitura só por URL assinada de até 15 minutos.
- **SeaweedFS no desenvolvimento**, só em loopback. A tarefa prova por execução: PUT pré-assinado, recusa de `Content-Length` diferente do assinado, GET sem assinatura recusado e expiração. **RustFS** é a alternativa se o SeaweedFS falhar em algum ponto.
- **URL pré-assinada de PUT que assina `Content-Type` e `Content-Length`**, com validade de 15 minutos. Como a fonte não confirma esse comportamento, a prova por execução é obrigatória, e o tamanho e o tipo reais são conferidos de novo no job, pelos bytes (`marcel`).
- **libvips** (`ruby-vips` e `image_processing`) normaliza a imagem: recusa acima de 40 megapixels, aplica a orientação, remove todos os metadados, reduz o lado maior para 1.568 px e regrava em JPEG, substituindo o objeto guardado.
- A chave do objeto é aleatória (`food-photos/<uuid>`) e fica em `food_photos.object_key`, que é dona do ciclo de vida da foto ([DATABASE_DESIGN.md](../DATABASE_DESIGN.md)). A retenção é de 30 dias após a análise.
- Fica por decidir o armazenamento de produção, que acompanha a [ADR 0015](0015-hosting-and-deployment.md). O adaptador isola essa escolha.

## Justificativa

O envio direto ao armazenamento mantém a API fora do caminho dos bytes. O adaptador S3 serve a qualquer provedor e a qualquer alternativa local. SeaweedFS e RustFS têm licença permissiva e estão ativos, ao contrário do MinIO. A libvips é a escolha usual com Rails e usa menos memória. As três gems novas são justificadas por esta ADR.

## Consequências

- Mais fácil: foto privada com acesso de prazo curto, sem passar pela API; troca de armazenamento sem mexer em Nutrition.
- Mais difícil: um serviço novo no `docker-compose.yml`; dependência nativa da libvips na máquina e no CI (`sudo apt install libvips42`); specs `:object_storage` falam com o SeaweedFS local.
- Fazer: provar o comportamento do PUT assinado; registrar o resultado no registro de fontes; promover a ADR a `Aceita` no encerramento da fase, ou trocar para o RustFS e registrar o motivo.

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

## Estado da decisão

Proposta
