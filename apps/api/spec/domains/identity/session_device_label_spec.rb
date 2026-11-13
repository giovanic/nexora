require "rails_helper"

RSpec.describe "sessions.device_label" do
  let(:label) { "iPhone de Mariana Souza" }
  let(:user_id) do
    Identity::Api.register(email: "ana@example.test", password: "correct horse battery", adult_confirmed: true,
                           time_zone: "America/Sao_Paulo", client: "mobile", device_label: label, ip: "203.0.113.7").user_id
  end

  def raw_label
    ActiveRecord::Base.connection.select_value("SELECT device_label FROM sessions")
  end

  it "is encrypted at rest and reads back decrypted" do
    user_id

    expect(raw_label).to be_present
    expect(raw_label).not_to include("Mariana")
    expect(Identity::Session.sole.device_label).to eq(label)
  end

  it "encrypts without a deterministic cipher, so equal labels differ at rest" do
    user_id
    Identity::Api.authenticate(email: "ana@example.test", password: "correct horse battery", client: "mobile", device_label: label, ip: nil)

    raw = ActiveRecord::Base.connection.select_values("SELECT device_label FROM sessions")
    expect(raw.uniq.size).to eq(2)
  end

  it "cuts the label to 100 characters before encrypting" do
    Identity::Api.register(email: "ana@example.test", password: "correct horse battery", adult_confirmed: true,
                           time_zone: "America/Sao_Paulo", client: "mobile", device_label: "x" * 300, ip: nil)

    expect(Identity::Session.sole.device_label).to eq("x" * 100)
  end

  it "is returned decrypted by the export and the session list" do
    user_id

    expect(Identity::Api.export_user_data(user_id).fetch(:sessions).first[:device_label]).to eq(label)
    expect(Identity::Api.sessions(user_id:).first.device_label).to eq(label)
  end

  it "survives a refresh" do
    token = Identity::Session.start!(user_id:, client: "mobile", device_label: label).last
    Identity::Api.refresh(token:)

    expect(Identity::Session.where.not(revoked_at: nil).count).to eq(1)
    expect(Identity::Session.active.pluck(:device_label)).to include(label)
  end
end
