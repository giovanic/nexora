require "rails_helper"
require "required_env"

RSpec.describe RequiredEnv do
  let(:complete) do
    {
      "DATABASE_URL" => "postgres://example",
      "REDIS_URL" => "redis://example",
      "SECRET_KEY_BASE" => "value",
      "ALLOWED_ORIGINS" => "https://example.test"
    }
  end

  it "returns nothing when every variable is present" do
    expect(described_class.missing(complete)).to eq([])
  end

  it "returns the names of absent variables" do
    expect(described_class.missing(complete.except("REDIS_URL", "ALLOWED_ORIGINS")))
      .to contain_exactly("REDIS_URL", "ALLOWED_ORIGINS")
  end

  it "treats a blank value as absent" do
    expect(described_class.missing(complete.merge("DATABASE_URL" => " "))).to eq([ "DATABASE_URL" ])
  end
end
