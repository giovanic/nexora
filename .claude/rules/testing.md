# Testes e evidência

Detalhes em `docs/engineering/TESTING_STRATEGY.md` e `docs/engineering/DEFINITION_OF_DONE.md`.

- TDD em todo código de produto, com `superpowers:test-driven-development`: veja o teste falhar antes de escrever o código.
- Nenhuma implementação sem critério de aceite.
- Testes proporcionais ao risco. Isolamento entre usuários, idempotência, concorrência, privacidade e regras de segurança de produto são obrigatórios onde se aplicam.
- Nunca afirme que testes passam sem executar o comando e ler a saída. Use `superpowers:verification-before-completion`.
- Bug corrigido tem teste de regressão, seguindo `superpowers:systematic-debugging`.
- APIs externas usam dublês na suíte comum. A fase também registra ao menos uma demonstração real.
- Avaliação de IA roda fora da suíte comum, porque custa dinheiro.
- Sem dados reais de usuários em testes.
- Separe em relatórios o que foi verificado do que foi apenas criado.
- `TODO` crítico só com responsável e justificativa.
