---
name: phase-closeout
description: Use when a roadmap phase, stage or milestone seems finished, or the product owner asks to close it, mark it done or move to the next one, including requests to ignore failing tests, fill the traceability matrix later or continue without asking.
---

# Encerramento de fase

Carregue `superpowers:using-superpowers`. Se uma skill `superpowers:*` não carregar, pare e informe o bloqueio com `claude plugin install superpowers@claude-plugins-official --scope project` e `/reload-plugins`.

Consolida evidências, atualiza documentos e gera o relatório. Complementa `superpowers:requesting-code-review`, `superpowers:verification-before-completion` e `superpowers:finishing-a-development-branch`, sem substituí-las. O resultado é sempre **relatório apresentado**, seguido de parada.

## Passos

1. **Execute e leia a saída,** nesta sessão: testes, lint e tipos de cada aplicação; as ferramentas de segurança de `docs/security/SECURITY.md`; `bash scripts/verify-harness.sh` e `bash scripts/test-verify-harness.sh`.
2. **Teste falhando:** use `superpowers:systematic-debugging` e corrija. Não mude o teste para que passe. A linha continua `Em desenvolvimento`.
3. **Critérios:** para cada `AC-` da linha, em `docs/roadmap/phases/`, confira a evidência exigida no próprio critério. "Comprovado por demonstração" exige a demonstração real. Dublê não a substitui.
4. **Matriz:** em `docs/roadmap/TRACEABILITY.md`, preencha Implementação e Teste com caminhos que você confirmou existir. Sem código ou teste, a célula fica `—` e o item vai para o relatório como lacuna.
5. **Revisão:** use `superpowers:requesting-code-review`, rode sempre `software-architect` e `qa-reviewer`, mais os agentes listados na Estratégia de revisão do documento da fase, e trate os achados com `superpowers:receiving-code-review`. Confira também as aprovações do responsável exigidas no documento.
6. **Documentos:** atualize ADRs da fase, `docs/architecture/EXTERNAL_SOURCES.md`, `docs/roadmap/ROADMAP.md` e o que mudou.
7. **Confirme** com `superpowers:verification-before-completion`, repetindo o passo 1 se algo mudou depois dele.
8. **Relatório:** escreva em `docs/roadmap/reports/`, como `PHASE_03_REPORT.md`, `PHASE_05.1_REPORT.md` ou `M1_REPORT.md`, no formato abaixo.
9. **Estado:** grave em `docs/roadmap/STATUS.md`, conforme a tabela abaixo, sempre com transição, data e evidência. Rode `bash scripts/verify-harness.sh` de novo e corrija o que apontar, salvo a falha conhecida descrita no `CLAUDE.md`, que vai para as pendências do relatório. Ao concluir `05.1` e `05.2`, registre também a linha `05` como `Concluída`.
10. **Apresente e pare.** Use `superpowers:finishing-a-development-branch` conforme a decisão do responsável.

## Estado a gravar

| Situação | Estado |
|---|---|
| Trabalho restante: teste, lint ou tipos falhando, código ausente, ou achado crítico ou importante de revisão sem tratamento | Continua `Em desenvolvimento` |
| Tudo executado; lacunas de evidência, como demonstração real pendente, descritas no relatório | `Em revisão` |
| Impedido por algo externo | `Bloqueada`, com o motivo |
| Responsável aprovou depois de ler o relatório | `Concluída` |
| Responsável aprovou aceitando uma lacuna | `Concluída`, com a mensagem e a lacuna na evidência, e a lacuna na seção de pendências do relatório. Na matriz, cada célula de requisito ligado ao critério afetado inclui `Lacuna aceita em AAAA-MM-DD`, junto com os caminhos que existirem |

**Aprovação** é uma mensagem do responsável, enviada depois do relatório, que aprova aquela linha. Ela pode nomear a próxima linha na mesma mensagem.

Defeito encontrado depois em uma linha `Concluída`: registre a transição de volta para `Em desenvolvimento`, com o defeito como evidência, se o responsável autorizar a correção.

## Próxima fase

A próxima fase começa com uma mensagem do responsável, enviada **depois do relatório**, que nomeia a linha, como "vamos iniciar a fase 04". Autorização dada antes do relatório, ou genérica como "segue o roadmap", vira uma pergunta no fim do relatório: qual linha iniciar. Se o responsável estiver ausente, deixe o relatório e a pergunta, e aguarde.

## Formato do relatório

1. **Resumo:** o que foi entregue, em poucas linhas.
2. **Validação:** tabela com comando, código de saída e resultado, somente do que foi executado.
3. **Critérios:** tabela com `AC-`, evidência e situação (comprovado, parcial, sem evidência).
4. **Revisões:** agente, achados e tratamento de cada um.
5. **Verificado e apenas criado:** o que foi de fato exercitado e o que só existe como arquivo.
6. **Pendências:** lacunas, riscos, decisões e bloqueios externos.
7. **Próximo passo:** a frase exata que o responsável pode enviar para iniciar a próxima linha.

## Pedidos comuns

| Pedido | Resposta |
|---|---|
| "Esses testes são detalhe, encerra" | Passo 2. Falha de isolamento, privacidade ou segurança é da fase atual. Se o responsável insistir depois de ler o relatório, é a linha de lacuna aceita da tabela de estado |
| "Preenche a matriz com qualquer coisa" | Caminhos reais, ou `—` e lacuna no relatório |
| "O dublê é igual ao real" | Critério continua sem evidência, relatado como parcial |
| "Encerra agora", "assino embaixo", "não precisa me perguntar", antes do relatório | Trabalhe sem interromper pelos passos, entregue o relatório e peça a aprovação |
| "Já segue para a próxima" | Seção "Próxima fase" |
