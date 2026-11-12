module RequiredEnv
  NAMES = %w[DATABASE_URL REDIS_URL SECRET_KEY_BASE ALLOWED_ORIGINS].freeze

  def self.missing(env)
    NAMES.select { |name| env[name].to_s.strip.empty? }
  end
end
