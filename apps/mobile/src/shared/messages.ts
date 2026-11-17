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
  unsupported_media_type: "Este formato de foto não é aceito. Tire a foto de novo pela câmera ou escolha uma imagem JPEG, PNG, WebP, HEIC ou HEIF.",
  invalid_photo: "A foto que chegou ao servidor não confere com a enviada. Tire ou escolha a foto de novo.",
  not_uploaded: "A foto não está mais disponível. Tire outra foto ou registre a refeição sem foto.",
  upload_expired: "O envio desta foto venceu. Vamos preparar o envio de novo.",
  analysis_retry_limit: "Esta foto já foi analisada o máximo de vezes. Tire outra foto ou registre a refeição sem foto.",
  analysis_quota_exceeded: "Você já enviou o máximo de fotos para análise hoje. Você pode registrar a refeição sem foto.",
  validation_failed: "Confira os dados. A quantidade de cada item deve ficar entre 1 e 2000 g.",
  entry_not_confirmable: "Esta refeição ainda não pode ser confirmada. Espere a análise terminar ou corrija os itens.",
  entry_not_editable: "Esta refeição não pode ser alterada agora. Espere a análise terminar.",
  entry_not_analyzable: "Esta refeição já está em análise ou concluída.",
  session_store_failed: "Não foi possível guardar a sua sessão com segurança neste aparelho.",
};

// Calm, plain messages. `fallback` covers the codes a screen knows better than we do.
const BY_FIELD: Record<string, string> = {
  byte_size: "A foto é grande demais. O limite é de 10 MB. Tire a foto de novo ou escolha outra.",
  meal_at: "A data e a hora da refeição não são aceitas. Ela deve ter acontecido nos últimos 30 dias.",
  content_type: "Não reconhecemos o formato desta foto. Escolha uma imagem JPEG, PNG, WebP, HEIC ou HEIF.",
};

export function errorMessage(failure: Failure, fallback = "Não foi possível concluir. Tente de novo."): string {
  if (failure.status === 429) return "Muitas tentativas. Tente novamente em alguns minutos.";
  if (failure.code === "network_error") return "Não foi possível falar com o servidor. Confira a conexão e tente de novo.";
  if (failure.status >= 500) return "Algo deu errado do nosso lado. Tente de novo em instantes.";
  if (failure.code === "validation_failed" && failure.field && BY_FIELD[failure.field]) return BY_FIELD[failure.field];
  return BY_CODE[failure.code] ?? fallback;
}
