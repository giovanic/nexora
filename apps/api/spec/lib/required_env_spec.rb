require "rails_helper"
require "required_env"

RSpec.describe RequiredEnv do
  let(:complete) { described_class::NAMES.to_h { |name| [ name, "value" ] } }

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
