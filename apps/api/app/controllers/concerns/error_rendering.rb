# Renders an error in the central format (API_DESIGN.md) from a controller,
# for codes that are not an exception. Messages never carry submitted values.
module ErrorRendering
  MESSAGES = {
    "invalid_credentials" => "E-mail ou senha incorretos.",
    "email_taken" => "Já existe uma conta com este e-mail. Você pode entrar com ele.",
    "invalid_time_zone" => "Não reconhecemos o fuso horário do aparelho.",
    "invalid_token" => "Este link de redefinição não vale mais. Peça um novo.",
    "profile_pending" => "Estamos preparando o seu perfil. Tente de novo em instantes.",
    "consent_required" => "Esta parte do app depende de um consentimento que você ainda não deu.",
    "outdated_version" => "O texto deste consentimento foi atualizado. Leia a versão atual antes de aceitar."
  }.freeze

  private

  def render_error(status, code = nil, details: nil)
    default_code, default_message = ApiErrorApp::ERRORS.fetch(Rack::Utils.status_code(status))
    code ||= default_code
    error = { code:, message: MESSAGES.fetch(code, default_message), request_id: request.request_id }
    error[:details] = details if details.present?

    render json: { error: }, status:
  end
end
