# Segurança e privacidade

Detalhes em `docs/security/SECURITY.md` e `docs/security/PRIVACY_AND_LGPD.md`.

- Dados de refeições, fotos, atividades e metas são tratados como dados sensíveis (LGPD).
- Consentimento específico por finalidade antes do tratamento. Autorização genérica não vale. Revogar é tão fácil quanto conceder.
- Nunca envie foto à IA sem o consentimento `food_photo_ai`. Remova EXIF, e não envie nome, e-mail ou histórico no prompt.
- Só provedores de IA cuja política documentada não usa as entradas para treinamento.
- Nunca coloque em logs, métricas ou erros: fotos, URLs assinadas, itens de refeição, valores nutricionais, tokens, senhas ou e-mails.
- Nenhum segredo no repositório ou no cliente. Não leia `.env` nem chaves privadas.
- Fotos ficam em armazenamento privado, com URLs assinadas de no máximo 15 minutos.
- Tokens de integração cifrados em nível de aplicação.
- Tabela nova com dados de usuário entra na exclusão de conta, na exportação e na retenção.
- Dados do Strava: visíveis só ao dono, nunca enviados à IA, apagados ao desconectar. O acesso não autorizado a token exige aviso ao Strava em 24 horas.
- Pontos de privacidade não têm parecer jurídico. Não trate os documentos como aconselhamento legal, e não remova pendências da revisão jurídica sem evidência.
