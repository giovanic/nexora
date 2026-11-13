require "rails_helper"
require "open3"

RSpec.describe "production boot" do
  let(:complete) do
    {
      "DATABASE_URL" => "postgres://user:pass@127.0.0.1:1/app",
      "REDIS_URL" => "redis://127.0.0.1:1/0",
      "SECRET_KEY_BASE" => "test-only-value",
      "ALLOWED_ORIGINS" => "https://example.test",
      "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => "boot-spec-primary-key-0123456789abcdef",
      "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => "boot-spec-deterministic-key-0123456789abcdef",
      "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => "boot-spec-key-derivation-salt-0123456789abcdef",
      "AUDIT_IP_HMAC_KEY" => "boot-spec-audit-ip-hmac-key-0123456789abcdef",
      "APP_WEB_URL" => "https://app.example.test"
    }
  end

  def boot(env, script = "exit 0")
    cleared = (RequiredEnv::NAMES + %w[LOG_LEVEL]).to_h { |name| [ name, nil ] }
    Bundler.with_original_env do
      Open3.capture2e(cleared.merge("RAILS_ENV" => "production").merge(env), "bundle", "exec", "rails", "runner", script, chdir: Rails.root.to_s)
    end
  end

  it "does not accept the debug log level in any letter case" do
    output, status = boot(complete.merge("LOG_LEVEL" => "DEBUG"), "puts Rails.logger.level")

    expect(status).to be_success, output
    expect(output.lines.last.strip).to eq(Logger::INFO.to_s)
  end

  it "does not accept the debug log level, which records exception messages" do
    output, status = boot(complete.merge("LOG_LEVEL" => "debug"), "puts Rails.logger.level")

    expect(status).to be_success, output
    expect(output.lines.last.strip).to eq(Logger::INFO.to_s)
  end

  it "writes the queue client's own log lines as JSON" do
    output, status = boot(complete, "puts Sidekiq.default_configuration.logger.formatter.class")

    expect(status).to be_success, output
    expect(output.lines.last.strip).to eq("Observability::JsonLogFormatter")
  end

  it "refuses to start without required variables, naming them and no values" do
    output, status = boot("DATABASE_URL" => "postgres://user:db-password-value@127.0.0.1:1/app")

    expect(status).not_to be_success
    expect(output).to include("REDIS_URL", "SECRET_KEY_BASE", "ALLOWED_ORIGINS")
    expect(output).not_to include("db-password-value")
  end

  it "starts when required variables are present" do
    output, status = boot(complete)

    expect(status).to be_success, output
  end

  %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
    AUDIT_IP_HMAC_KEY
    APP_WEB_URL
  ].each do |name|
    it "refuses to boot without #{name}" do
      output, status = boot(complete.merge(name => nil))

      expect(status).not_to be_success
      expect(output).to include(name)
    end
  end

  %w[
    ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
    ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
    AUDIT_IP_HMAC_KEY
  ].each do |name|
    it "refuses to boot when #{name} is shorter than 32 characters, naming it and not the value" do
      output, status = boot(complete.merge(name => "short-secret-value"))

      expect(status).not_to be_success
      expect(output).to include(name)
      expect(output).not_to include("short-secret-value")
    end
  end

  {
    "http://app.example.test" => "not https",
    "https://app.example.test/" => "trailing slash",
    "app.example.test" => "no scheme",
    "https://app.example.test/path" => "with a path"
  }.each do |value, why|
    it "refuses to boot when APP_WEB_URL is #{why}, naming it and not the value" do
      output, status = boot(complete.merge("APP_WEB_URL" => value))

      expect(status).not_to be_success
      expect(output).to include("APP_WEB_URL")
      expect(output).not_to include(value)
    end
  end

  it "refuses to boot without the encryption keys" do
    output, status = boot(complete.reject { |name, _| name.start_with?("ACTIVE_RECORD_ENCRYPTION") })

    expect(status).not_to be_success
    expect(output).to include("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
  end

  it "uses the queue service as cache store" do
    output, status = boot(complete, "puts Rails.cache.class")

    expect(status).to be_success, output
    expect(output.lines.last.strip).to eq("ActiveSupport::Cache::RedisCacheStore")
  end

  it "configures Active Record Encryption from the environment" do
    script = "e = ActiveRecord::Encryption.config; puts [e.primary_key, e.deterministic_key, e.key_derivation_salt].join(',')"
    output, status = boot(complete, script)

    expect(status).to be_success, output
    expect(output.lines.last.strip).to eq("boot-spec-primary-key-0123456789abcdef,boot-spec-deterministic-key-0123456789abcdef,boot-spec-key-derivation-salt-0123456789abcdef")
  end
end
