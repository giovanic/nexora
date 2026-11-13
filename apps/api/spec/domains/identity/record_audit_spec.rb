require "rails_helper"

RSpec.describe Identity::RecordAudit do
  let(:user_ref) { SecureRandom.uuid }

  it "records the action, the metadata of its closed list and a keyed hash of the IP" do
    audit = described_class.call(action: "sign_in", user_ref:, metadata: { client: "web" }, ip: "198.51.100.4")

    expect(audit.reload).to have_attributes(action: "sign_in", user_ref:, metadata: { "client" => "web" }, occurred_at: be_present)
    expect(audit.ip_hmac).to eq(OpenSSL::HMAC.hexdigest("SHA256", Rails.configuration.x.audit_ip_hmac_key, "198.51.100.4"))
  end

  it "keeps the IP hash empty when there is no IP" do
    expect(described_class.call(action: "sign_in_failed", ip: nil).ip_hmac).to be_nil
  end

  it "refuses an action outside the list" do
    expect { described_class.call(action: "password_typed", ip: nil) }.to raise_error(ArgumentError)
  end

  it "refuses a metadata field the action does not list" do
    expect { described_class.call(action: "sign_in_failed", metadata: { email: "ana@example.test" }, ip: nil) }
      .to raise_error(ArgumentError) { |error| expect(error.message).not_to include("ana@example.test") }
  end

  it "refuses a value outside the field's closed list" do
    expect { described_class.call(action: "sign_in", user_ref:, metadata: { client: "Ana's laptop" }, ip: nil) }
      .to raise_error(ArgumentError) { |error| expect(error.message).not_to include("Ana") }
  end

  it "keeps recorded events unchangeable" do
    audit = described_class.call(action: "sign_in_failed", ip: nil)

    expect { audit.update!(action: "sign_in") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end
