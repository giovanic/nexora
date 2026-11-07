module AllowedOrigins
  LOCAL_WEB_APP = "http://localhost:5173".freeze

  # Without configuration, production allows no origin at all. A wildcard is
  # dropped, because the API must never be open to every site.
  def self.from(env, environment: "development")
    configured = env["ALLOWED_ORIGINS"].to_s.split(",").map(&:strip).reject { |origin| origin.empty? || origin == "*" }
    return configured if configured.any? || env.key?("ALLOWED_ORIGINS")

    environment == "production" ? [] : [ LOCAL_WEB_APP ]
  end
end
