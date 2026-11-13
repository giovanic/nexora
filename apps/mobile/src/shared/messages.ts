import type { Failure } from "./api";

const BY_CODE: Record<string, string> = {
  invalid_credentials: "E-mail ou senha incorretos.",
  unauthorized: "Sua sessão terminou. Entre de novo.",
  email_taken: "Já existe uma conta com este e-mail. Você pode entrar com ele.",
  invalid_time_zone: "Não reconhecemos o fuso horário do aparelho.",
  invalid_token: "Este link de redefinição não vale mais. Peça um novo.",
  profile_pending: "Ainda estamos preparando o seu perfil. Tente de novo em instantes.",
  consent_required: "Esta parte depende do consentimento de dados de saúde.",
  outdated_version: "O texto deste consentimento foi atualizado. Leia a versão atual antes de aceitar.",
  revocation_pending: "A retirada do seu consentimento anterior ainda está sendo aplicada. Tente de novo mais tarde.",
  session_store_failed: "Não foi possível guardar a sua sessão com segurança neste aparelho.",
};

// Calm, plain messages. `fallback` covers the codes a screen knows better than we do.
export function errorMessage(failure: Failure, fallback = "Não foi possível concluir. Tente de novo."): string {
  if (failure.status === 429) return "Muitas tentativas. Tente novamente em alguns minutos.";
  if (failure.code === "network_error") return "Não foi possível falar com o servidor. Confira a conexão e tente de novo.";
  if (failure.status >= 500) return "Algo deu errado do nosso lado. Tente de novo em instantes.";
  return BY_CODE[failure.code] ?? fallback;
}
