require "json"

# Rendered by ActionDispatch::ShowExceptions for every unhandled error. It is a
# plain Rack app, not a controller: a controller would parse the request body
# again and fail a second time on the malformed JSON that caused the error.
class ApiErrorApp
  ERRORS = {
    400 => [ "bad_request", "A requisição está malformada." ],
    401 => [ "unauthorized", "É preciso entrar para continuar." ],
    403 => [ "forbidden", "Esta ação não está autorizada." ],
    404 => [ "not_found", "O recurso não foi encontrado." ],
    405 => [ "method_not_allowed", "Este método não é aceito neste recurso." ],
    406 => [ "not_acceptable", "Este formato de resposta não é aceito." ],
    409 => [ "conflict", "A ação entra em conflito com o estado atual." ],
    413 => [ "payload_too_large", "O conteúdo enviado é grande demais." ],
    415 => [ "unsupported_media_type", "Este formato de conteúdo não é aceito." ],
    422 => [ "unprocessable", "Não foi possível processar a requisição." ],
    429 => [ "too_many_requests", "Muitas requisições. Tente novamente em instantes." ]
  }.freeze
  OTHER_CLIENT_ERROR = [ "request_error", "A requisição não pôde ser atendida." ].freeze
  SERVER_ERROR = [ "internal_error", "Ocorreu um erro interno. Tente novamente." ].freeze

  def call(env)
    status = env["PATH_INFO"].delete_prefix("/").to_i
    code, message = describe(status)

    body = { error: { code:, message:, request_id: env["action_dispatch.request_id"] } }
    [ status, { "content-type" => "application/json; charset=utf-8" }, [ JSON.generate(body) ] ]
  end

  private

  def describe(status)
    return SERVER_ERROR if status >= 500

    ERRORS.fetch(status, OTHER_CLIENT_ERROR)
  end
end
