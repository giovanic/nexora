# Renders an error in the central format (API_DESIGN.md) from a controller,
# for codes that are not an exception. Messages never carry submitted values.
module ErrorRendering
  MESSAGES = {
    "invalid_credentials" => "E-mail ou senha incorretos.",
    "email_taken" => "Já existe uma conta com este e-mail. Você pode entrar com ele.",
    "invalid_time_zone" => "Não reconhecemos o fuso horário do aparelho."
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
