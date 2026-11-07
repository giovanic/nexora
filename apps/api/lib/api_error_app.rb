require "json"

# Rendered by ActionDispatch::ShowExceptions for every unhandled error. It is a
# plain Rack app, not a controller: a controller would parse the request body
# again and fail a second time on the malformed JSON that caused the error.
class ApiErrorApp
  ERRORS = {
    400 => [ "bad_request", "A requisição está malformada." ],
    404 => [ "not_found", "O recurso não foi encontrado." ],
    500 => [ "internal_error", "Ocorreu um erro interno. Tente novamente." ]
  }.freeze

  def call(env)
    status = env["PATH_INFO"].delete_prefix("/").to_i
    code, message = ERRORS.fetch(normalize(status))

    body = { error: { code:, message:, request_id: env["action_dispatch.request_id"] } }
    [ normalize(status), { "content-type" => "application/json; charset=utf-8" }, [ JSON.generate(body) ] ]
  end

  private

  def normalize(status)
    return status if ERRORS.key?(status)

    status >= 500 ? 500 : 400
  end
end
