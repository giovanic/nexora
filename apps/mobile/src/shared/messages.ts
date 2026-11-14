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
  consent_operator_mismatch: "O consentimento de envio de fotos foi atualizado. Leia o texto atual antes de enviar uma foto.",
  unsupported_media_type: "Este formato de foto não é aceito. Tire a foto de novo pela câmera ou escolha uma imagem JPEG, PNG ou WebP.",
  invalid_photo: "A foto que chegou ao servidor não confere com a enviada. Tire ou escolha a foto de novo.",
  not_uploaded: "A foto não chegou ao servidor. Tire ou escolha a foto de novo.",
  validation_failed: "Confira os dados. A quantidade de cada item deve ficar entre 1 e 2000 g.",
  entry_not_confirmable: "Esta refeição ainda não pode ser confirmada. Espere a análise terminar ou corrija os itens.",
  entry_not_editable: "Esta refeição não pode ser alterada agora. Espere a análise terminar.",
  entry_not_analyzable: "Esta refeição já está em análise ou concluída.",
  session_store_failed: "Não foi possível guardar a sua sessão com segurança neste aparelho.",
};

// Calm, plain messages. `fallback` covers the codes a screen knows better than we do.
export function errorMessage(failure: Failure, fallback = "Não foi possível concluir. Tente de novo."): string {
  if (failure.status === 429) return "Muitas tentativas. Tente novamente em alguns minutos.";
  if (failure.code === "network_error") return "Não foi possível falar com o servidor. Confira a conexão e tente de novo.";
  if (failure.status >= 500) return "Algo deu errado do nosso lado. Tente de novo em instantes.";
  return BY_CODE[failure.code] ?? fallback;
}
