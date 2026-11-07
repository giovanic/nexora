---
paths:
  - "apps/mobile/**"
---

# Aplicativo móvel (Expo e TypeScript)

Detalhes em `docs/engineering/CODING_STANDARDS.md`.

- Antes de usar uma API do Expo ou do React Native, confira a versão em `package.json` e a documentação daquela versão.
- TypeScript estrito. Tipos da API vêm do contrato OpenAPI.
- Sem regra de negócio no cliente.
- Componentize, e separe estado de apresentação.
- Toda tela trata carregando, vazio e erro, com testes.
- Trate permissão de câmera negada e falha de rede sem perder a foto capturada.
- Credenciais em armazenamento seguro do sistema, nunca em `AsyncStorage`.
- Variável `EXPO_PUBLIC_` vai para o aplicativo: nunca coloque segredo nela.
- Acessibilidade: rótulos para leitor de tela e áreas de toque adequadas.
- Registro por foto com o mínimo de toques. Corrigir é possível, nunca obrigatório.
- Estimativas sempre em faixa. Sem cor de alerta ou comparação com limite para calorias.
- Lembre que o app não atualiza junto com o servidor: mudanças na API são compatíveis.
