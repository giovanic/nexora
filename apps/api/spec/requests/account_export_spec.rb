require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"

RSpec.describe "account export", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }

  def export(password: IdentityHelpers::PASSWORD, headers: bearer(token), env: {})
    post "/api/v1/account/export", params: { password: }, headers:, env:, as: :json
  end

  describe "POST /api/v1/account/export" do
    it "wrong password is 401 and exports nothing" do
      audits = Identity::AuditEvent.count

      export(password: "wrong password!")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_credentials")
      expect(response.body).not_to include("ana@example.test")
      expect(Identity::AuditEvent.count).to eq(audits)
      expect_response_to_match_contract
    end

    it "a missing password is 401 too" do
      post "/api/v1/account/export", params: {}, headers: bearer(token), as: :json

      expect(response).to have_http_status(:unauthorized)
      expect_response_to_match_contract
    end

    it "needs a session" do
      post "/api/v1/account/export", params: { password: IdentityHelpers::PASSWORD }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect_response_to_match_contract
    end

    it "works without the health_data consent" do
      export

      expect(response).to have_http_status(:ok)
    end

    it "export has every registered context and no other person's data" do
      other = mobile_token(email: "bia@example.test")
      other_id = Identity::User.find_by!(email: "bia@example.test").id
      post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(other), as: :json
      run_publisher

      export

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body.keys).to match_array(Shared::DataRegistry.export(user_id:).keys.map(&:to_s))
      expect(body.keys).to include("identity", "user_profile", "shared")
      expect(body.dig("identity", "user", "id")).to eq(user_id)
      expect(body.dig("identity", "sessions").map { |s| s["client"] }).to eq([ "mobile" ])
      expect(body.dig("user_profile", "profile")).to be_present
      expect(response.body).not_to include("bia@example.test", other_id)
      expect(response.body).not_to match(/password_digest|token_digest|ip_hmac|reset_token/)
      expect_response_to_match_contract
    end

    it "records an audit event without content" do
      export

      audit = Identity::AuditEvent.where(action: "account_exported").sole
      expect(audit).to have_attributes(user_ref: user_id, metadata: {})
    end

    it "limits attempts by IP: 10 in 3 minutes" do
      10.times { export(password: "wrong password!") }
      export

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("180")
      expect_response_to_match_contract
    end

    it "response is no-store and never logged" do
      log_path = Rails.root.join("log/test.log")
      offset = File.size(log_path)
      level = Rails.logger.level
      Rails.logger.level = Logger::DEBUG

      export

      Rails.logger.flush if Rails.logger.respond_to?(:flush)
      text = File.binread(log_path, nil, offset).force_encoding("UTF-8")
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.body).to include("ana@example.test")
      expect(text).to include("/api/v1/account/export")
      expect(text).not_to include("ana@example.test", IdentityHelpers::PASSWORD, token)
      expect(Identity::AuditEvent.pluck(:metadata).to_s).not_to include("ana@example.test")
    ensure
      Rails.logger.level = level
    end

    it "writes no file" do
      before = Dir.glob(Rails.root.join("{tmp,storage,public}/**/*")).size

      export

      expect(Dir.glob(Rails.root.join("{tmp,storage,public}/**/*")).size).to eq(before)
    end
  end
end
