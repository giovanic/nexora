# Avaliação do Food AI: 2026-11-14 (pre-provider)

Etapa sem provedor: mede só a correspondência dos nomes esperados com o catálogo. Dataset v1: 60 imagens.

## Correspondência com o catálogo (antes de qualquer provedor)

Para cada nome esperado nas anotações, o catálogo carregado (`food_catalog:load`) é consultado com `FoodCatalog::Api.match`. "Certo" é achar o item que o projeto aceita para o nome (`catalog_truth` em `annotations.yml`); "errado" é achar outro item, ou achar algum quando não há item aceitável.

Limiar atual `MATCH_THRESHOLD` = 0,45: 105 de 178 itens esperados (59,0%) encontram algum item; entre os 40 nomes distintos, 28 certos, 1 errados, 10 sem achar o item aceito, 1 sem item aceitável e sem achar.

| Limiar | Certos | Errados | Sem achar o aceito | Sem item aceitável e sem achar |
|---|---|---|---|---|
| 0,30 | 30 | 9 | 1 | 0 |
| 0,35 | 29 | 7 | 3 | 1 |
| 0,40 | 28 | 4 | 7 | 1 |
| 0,45 | 28 | 1 | 10 | 1 |
| 0,50 | 25 | 1 | 13 | 1 |
| 0,55 | 21 | 0 | 18 | 1 |
| 0,60 | 17 | 0 | 22 | 1 |
| 0,65 | 11 | 0 | 28 | 1 |
| 0,70 | 6 | 0 | 33 | 1 |

**Limiar sugerido: 0,55**, um candidato, não uma decisão: é o menor com menos correspondências erradas e, entre esses, mais certas. Do limiar atual (0,45) ao sugerido (0,55): -7 certos, -1 errados.

Ressalva: os nomes vêm das anotações do projeto, não de saídas dos provedores. Os nomes que um modelo escreve ("peito de frango grelhado", "arroz") são outros, então a rodada real precisa recalibrar o limiar antes de qualquer mudança em `MATCH_THRESHOLD`, que é do responsável.

Correspondências erradas no limiar sugerido: nenhuma. Subir o limiar não corrige uma correspondência errada de similaridade alta: isso pede ajuste do catálogo ou dos nomes.

| Nome esperado | Item mais próximo | Similaridade | Item aceito |
|---|---|---|---|
| abacate | Abacate cru | 0,67 | Abacate cru |
| alface | Alface crua | 0,58 | Alface crua |
| arroz | Arroz com feijão | 0,35 | Arroz branco cozido |
| arroz branco | Arroz branco cozido | 0,65 | Arroz branco cozido |
| arroz integral | Arroz integral cozido | 0,68 | Arroz integral cozido |
| batata | Batata cozida | 0,46 | Batata cozida / Batata assada / Batata crua |
| batata assada | Batata assada | 1,00 | Batata assada |
| batata frita | Batata cozida | 0,33 | (nenhum) |
| batata-doce | Batata-doce assada | 0,61 | Batata-doce assada / Batata-doce crua |
| beterraba | Beterraba cozida | 0,59 | Beterraba cozida |
| bife | Bife acebolado | 0,33 | Bife de coxão mole grelhado |
| brócolis | Brócolis cozido | 0,56 | Brócolis cozido |
| carne | Carne-seca | 0,55 | Acém cozido / Bife de coxão mole grelhado / Lagarto assado / Peito bovino cozido / Carne moída refogada |
| carne bovina | Carne bovina em conserva cozida | 0,45 | Acém cozido / Bife de coxão mole grelhado / Lagarto assado / Peito bovino cozido |
| carne moída | Carne moída refogada | 0,60 | Carne moída refogada / Carne moída crua |
| carne suína | Carne suína moída cozida | 0,55 | Pernil suíno assado / Lombo suíno assado / Filé suíno assado / Carne suína moída cozida / Costelinha suína cozida |
| cebola | Cebola crua | 0,64 | Cebola crua |
| cenoura | Cenoura cozida | 0,57 | Cenoura cozida / Cenoura crua |
| costela | - | - | Costelinha suína cozida |
| couve | Couve crua | 0,60 | Couve-manteiga cozida / Couve crua |
| couve-flor | Couve-flor cozida | 0,69 | Couve-flor cozida |
| coxa de frango | Coxa de frango cozida | 0,75 | Coxa de frango cozida / Sobrecoxa de frango assada |
| ervilha | Ervilha cozida | 0,53 | Ervilha cozida |
| farofa | Farofa de ovo | 0,50 | Farofa simples / Farofa de ovo |
| feijão | Feijão tropeiro | 0,44 | Feijão-carioca cozido / Feijão-preto cozido |
| feijão branco | Feijão-branco cozido | 0,67 | Feijão-branco cozido |
| frango | Frango com quiabo | 0,39 | Frango assado (sem pele) / Peito de frango assado / Coxa de frango cozida / Sobrecoxa de frango assada |
| frango grelhado | Frango assado (sem pele) | 0,30 | Frango assado (sem pele) / Peito de frango assado |
| linguiça | Linguiça de porco frita | 0,38 | Linguiça de porco frita |
| milho | Óleo de milho | 0,43 | Milho-verde cozido |
| ovo cozido | Ovo cozido | 1,00 | Ovo cozido |
| ovo frito | Ovo frito | 1,00 | Ovo frito |
| ovo mexido | Ovo mexido | 1,00 | Ovo mexido |
| peito de frango | Peito de frango frito | 0,89 | Peito de frango assado / Peito de frango frito |
| peixe | Moqueca de peixe | 0,35 | Tilápia assada / Bagre assado / Cavala assada / Salmão assado |
| pepino | Pepino cru | 0,64 | Pepino cru |
| pimentão | Pimentão verde cru | 0,47 | Pimentão verde cru / Pimentão vermelho cru |
| salmão | Salmão assado | 0,50 | Salmão assado |
| tomate | Tomate cru | 0,64 | Tomate cru |
| vagem | Vagem cozida | 0,46 | Vagem cozida |

## Método e limites

- Cada foto passa por `FoodAi::NormalizePhoto`, pelo adaptador do provedor, por `FoodAi::ValidateOutput`, por `FoodCatalog::Api.match` e por `Nutrition::Api.estimate`. Nada é gravado no banco.
- Itens são comparados pela chave do catálogo (o item que o nome encontra) e, sem item, pelo nome sem acento nem caixa.
- Erro de porção e acerto da faixa só contam itens esperados com peso (Nutrition5k) que o provedor também listou.
- Latência: tempo da chamada que respondeu (sem a espera entre tentativas). Percentil pelo método do posto mais próximo.
- Erro transitório (timeout, 429, 5xx) tem até 3 tentativas; saída inválida não é repetida.
- As anotações de pratos brasileiros foram feitas pelo projeto, olhando cada imagem, só com o que se vê com clareza. A precisão é um limite inferior: o prato pode ter itens que a anotação não lista.
- Sem dados de usuário. Sem meta inicial inventada: as metas da fase saem desta primeira medição.
