# Fitness Companion (nome de trabalho)

Plataforma de bem-estar e evolução pessoal: registro de refeições por foto, com estimativa nutricional honesta, metas de hábito, atividades com integração oficial ao Strava e um sistema de jogo que premia constância.

## Estado atual

O projeto está na construção do **Engineering Harness**. Ainda não há aplicação validada. As pastas `apps/` e `packages/` contêm só o que os geradores criaram, sem aprovação do processo. Veja o estado de cada fase em [STATUS.md](docs/roadmap/STATUS.md).

O harness é o sistema de engenharia que governa o desenvolvimento: documentos, regras, agentes revisores, skills e verificações que permitem a qualquer nova sessão do Claude Code entender o projeto e continuar de onde parou.

## Pré-requisitos

- Git, Bash e Python 3.
- Claude Code.
- Plugin Superpowers, obrigatório. A configuração do projeto o habilita, mas cada máquina precisa instalá-lo uma vez:

```bash
claude plugin install superpowers@claude-plugins-official --scope project
```

Depois, execute `/reload-plugins` no Claude Code ou abra uma nova sessão. Versão validada: 7.0.0.

## Verificar o harness

```bash
bash scripts/verify-harness.sh        # Reprova com código diferente de zero
bash scripts/test-verify-harness.sh   # Prova que o verificador detecta os defeitos dos cenários
```

## Como trabalhar

Peça ao Claude Code: **"Vamos iniciar a fase NN"**. Ele segue o [protocolo de execução](docs/roadmap/PHASE_EXECUTION_PROTOCOL.md): verifica dependências por evidência, apresenta um plano, e só implementa depois da sua aprovação. Nenhuma fase avança sozinha.

## Documentação

| Área | Onde |
|---|---|
| Instruções para o Claude Code | [CLAUDE.md](CLAUDE.md) |
| Produto | [docs/product](docs/product/PRODUCT_VISION.md) |
| Arquitetura e decisões | [docs/architecture](docs/architecture/SYSTEM_OVERVIEW.md), [ADRs](docs/architecture/decisions/README.md) |
| Segurança, privacidade e saúde | [docs/security](docs/security/SECURITY.md) |
| Padrões, testes e qualidade | [docs/engineering](docs/engineering/CODING_STANDARDS.md) |
| Roadmap e fases | [docs/roadmap](docs/roadmap/ROADMAP.md) |
| Operação | [docs/operations](docs/operations/LOCAL_DEVELOPMENT.md) |

## Stack de referência

Rails API, PostgreSQL, Redis, Sidekiq, React com Vite, Expo, TypeScript, armazenamento compatível com S3, REST com OpenAPI, Docker e GitHub Actions. As versões são confirmadas na Fase 01 ([ADR 0002](docs/architecture/decisions/0002-technology-baseline.md)).

## Aviso

Este produto não é ferramenta médica. Estimativas nutricionais são aproximações e não substituem orientação profissional.
# nexora
