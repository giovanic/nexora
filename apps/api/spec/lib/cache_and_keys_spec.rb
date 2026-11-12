require "rails_helper"

RSpec.describe "cache and encryption keys outside production" do
  it "uses an in-memory cache store in the test environment" do
    expect(Rails.cache).to be_a(ActiveSupport::Cache::MemoryStore)
  end

  it "has encryption keys and the other Phase 02 settings available" do
    config = ActiveRecord::Encryption.config

    expect([ config.primary_key, config.deterministic_key, config.key_derivation_salt ]).to all(be_present)
    expect(Rails.configuration.x.audit_ip_hmac_key).to be_present
    expect(Rails.configuration.x.app_web_url).to be_present
  end
end
