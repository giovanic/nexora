# Desenvolvimento local

## Estado atual (2026-11-05)

O harness é a parte governada. Os comandos da Fase 01 em diante estão marcados como "a confirmar".

Pastas `apps/` e `packages/` geradas por ferramentas existem no repositório desde 2026-11-05, fora do processo do harness e sem código de negócio. O responsável decidiu mantê-las. Com a Fase 01 em `Não iniciada`, o check `scope` do verificador reprova por causa delas. Elas não foram validadas: não as trate como base aprovada, nem use os comandos delas como comandos do projeto.

## Pré-requisitos do harness

| Ferramenta | Uso | Encontrada nesta máquina |
|---|---|---|
| Git | Versionamento | Sim |
| Python 3 | Verificador do harness (biblioteca padrão) | 3.10.12 |
| Bash | Scripts | Sim |
| Claude Code | Agente de desenvolvimento | 2.1.316 |
| Superpowers | Metodologia obrigatória | 7.0.0 |

## Instalar o Superpowers

`.claude/settings.json` habilita o plugin, mas isso **não o baixa** em uma máquina nova. Rode uma vez:

```bash
claude plugin install superpowers@claude-plugins-official --scope project
```

Depois, execute `/reload-plugins` no Claude Code ou abra uma nova sessão. Confirme com:

```bash
claude plugin list
```

Versão validada: 7.0.0. Se a versão instalada for outra, leia as instruções atuais de cada skill antes de assumir que nada mudou.

## Verificar o harness

```bash
bash scripts/verify-harness.sh        # Verifica o harness; retorna diferente de zero em falha
bash scripts/test-verify-harness.sh   # Prova que o verificador detecta os defeitos dos cenários
```

## Versões encontradas nesta máquina

Registro de 2026-11-05. **Não são as versões do projeto**, definidas na [ADR 0002](../architecture/decisions/0002-technology-baseline.md).

| Ferramenta | Versão |
|---|---|
| Ruby | 3.3.4 |
| Rails | 8.1.4 |
| Node | 22.18.0 |
| npm | 10.9.3 |
| Docker | 27.3.1 |
| PostgreSQL | 17.0 |
| Redis | 7.4.1 |
| `gh` | Não instalado |

## Observações

- O ambiente é WSL 2. Prefira manter o repositório no sistema de arquivos Linux. Arquivos editados pelo Windows podem ter fim de linha CRLF, que o verificador aceita nos documentos. Os scripts precisam de LF, garantido por `.gitattributes`.
- **`.env.example`:** a regra `Read(**/.env.*)` em `.claude/settings.json` bloqueia a leitura pelas ferramentas de arquivo do Claude Code, e uma regra `allow` não abre exceção. Para alterar esse arquivo, o responsável edita, ou o Claude pede autorização para ajustar a regra.
- O diretório `.superpowers/` é espaço de trabalho temporário, ignorado pelo Git.

## A partir da Fase 01 (a confirmar)

O [plano da Fase 01](../roadmap/phases/PHASE_01_FOUNDATION.md) substitui esta seção por comandos testados a partir de um clone limpo (NFR-OPS-001). A intenção:

```text
Subir PostgreSQL, Redis e serviços locais com Docker
Preparar e iniciar a API Rails e o Sidekiq
Iniciar o painel web com Vite
Iniciar o app com Expo
Rodar testes, lint e tipos de cada aplicação
```

Variáveis em [ENVIRONMENT_VARIABLES.md](ENVIRONMENT_VARIABLES.md).
