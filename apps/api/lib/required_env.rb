module RequiredEnv
  NAMES = %w[
    DATABASE_URL REDIS_URL SECRET_KEY_BASE ALLOWED_ORIGINS
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT AUDIT_IP_HMAC_KEY APP_WEB_URL
  ].freeze

  # Keys and salts: a short one is guessable, so it is refused, not just a missing one.
  MINIMUM_LENGTH = {
    "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => 32, "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => 32,
    "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => 32, "AUDIT_IP_HMAC_KEY" => 32
  }.freeze
  # An https origin, with no path and no trailing slash: links are built as "#{APP_WEB_URL}/path".
  WEB_URL = %r{\Ahttps://[A-Za-z0-9.-]+(:\d{1,5})?\z}

  def self.missing(env)
    NAMES.select { |name| env[name].to_s.strip.empty? }
  end

  # Names of variables that are present but malformed. Never the values.
  def self.invalid(env)
    short = MINIMUM_LENGTH.select { |name, length| present?(env, name) && env[name].to_s.length < length }.keys
    bad_url = present?(env, "APP_WEB_URL") && !WEB_URL.match?(env["APP_WEB_URL"].to_s) ? [ "APP_WEB_URL" ] : []
    short + bad_url
  end

  def self.present?(env, name)
    !env[name].to_s.strip.empty?
  end
  private_class_method :present?
end
