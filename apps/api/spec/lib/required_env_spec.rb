require "rails_helper"
require "required_env"

RSpec.describe RequiredEnv do
  let(:complete) do
    described_class::NAMES.to_h { |name| [ name, "value" ] }.merge(described_class::MINIMUM_LENGTH.keys.to_h { |name| [ name, "k" * 32 ] })
                           .merge("APP_WEB_URL" => "https://app.example.test")
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

  describe ".invalid" do
    it "returns nothing for a well-formed environment" do
      expect(described_class.invalid(complete)).to eq([])
    end

    it "names a key shorter than 32 characters" do
      expect(described_class.invalid(complete.merge("AUDIT_IP_HMAC_KEY" => "k" * 31))).to eq([ "AUDIT_IP_HMAC_KEY" ])
    end

    it "names an APP_WEB_URL that is not an https origin without a trailing slash" do
      [ "http://a.test", "https://a.test/", "a.test", "https://a.test/x", "https://" ].each do |value|
        expect(described_class.invalid(complete.merge("APP_WEB_URL" => value))).to eq([ "APP_WEB_URL" ]), value
      end
    end

    it "does not report an absent variable, which .missing does" do
      expect(described_class.invalid(complete.except("APP_WEB_URL", "AUDIT_IP_HMAC_KEY"))).to eq([])
    end
  end
end
