require "rails_helper"
require "open3"

RSpec.describe "production boot" do
  def boot(env)
    cleared = %w[DATABASE_URL REDIS_URL SECRET_KEY_BASE ALLOWED_ORIGINS].to_h { |name| [ name, nil ] }
    Bundler.with_original_env do
      Open3.capture2e(cleared.merge("RAILS_ENV" => "production").merge(env), "bundle", "exec", "rails", "runner", "exit 0", chdir: Rails.root.to_s)
    end
  end

  it "refuses to start without required variables, naming them and no values" do
    output, status = boot("DATABASE_URL" => "postgres://user:db-password-value@127.0.0.1:1/app")

    expect(status).not_to be_success
    expect(output).to include("REDIS_URL", "SECRET_KEY_BASE", "ALLOWED_ORIGINS")
    expect(output).not_to include("db-password-value")
  end

  it "starts when required variables are present" do
    output, status = boot(
      "DATABASE_URL" => "postgres://user:pass@127.0.0.1:1/app",
      "REDIS_URL" => "redis://127.0.0.1:1/0",
      "SECRET_KEY_BASE" => "test-only-value",
      "ALLOWED_ORIGINS" => "https://example.test"
    )

    expect(status).to be_success, output
  end
end
