require "required_env"

if Rails.env.production?
  missing = RequiredEnv.missing(ENV.to_h)

  raise "Variáveis de ambiente obrigatórias ausentes: #{missing.join(', ')}" if missing.any?
end
