require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"

RSpec.describe "account deletion", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }

  before { allow(Identity::EraseAccountJob).to receive(:perform_async) }

  def delete_account(password: IdentityHelpers::PASSWORD, headers: bearer(token), env: {})
    delete "/api/v1/account", params: { password: }, headers:, env:, as: :json
  end

  def sessions_status(session_token)
    get "/api/v1/sessions", headers: bearer(session_token)
    response.status
  end

  describe "DELETE /api/v1/account" do
    it "answers 202 and schedules the erasure" do
      delete_account

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
      expect(Identity::AccountDeletion.where(user_id:).count).to eq(1)
      expect_response_to_match_contract
    end

    it "deletion revokes sessions on every device at once" do
      sign_in(client: "mobile", device_label: "iPad")
      tablet = response.parsed_body.fetch("token")
      sign_in(client: "web")
      web_cookie = session_cookie_header[/\A__Host-session=[^;]+/]
      expect([ token, tablet ].map { |session_token| sessions_status(session_token) }).to eq([ 200, 200 ])
      expect(Identity::Session.where(user_id:, revoked_at: nil).count).to eq(3)

      delete_account

      expect(response).to have_http_status(:accepted)
      expect([ token, tablet ].map { |session_token| sessions_status(session_token) }).to eq([ 401, 401 ])
      get "/api/v1/sessions", headers: { "Cookie" => web_cookie }
      expect(response).to have_http_status(:unauthorized)
      expect(Identity::Session.where(user_id:, revoked_at: nil)).to be_empty
      sign_in
      expect(response).to have_http_status(:unauthorized)
    end

    it "with the web cookie, forgets it" do
      sign_up(email: "bia@example.test", client: "web")

      delete "/api/v1/account", params: { password: IdentityHelpers::PASSWORD }, headers: { "Origin" => IdentityHelpers::WEB_ORIGIN }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(session_cookie_header).to match(/max-age=0|expires=Thu, 01 Jan 1970/i)
      expect(Identity::AccountDeletion.sole.user_id).to eq(Identity::User.find_by!(email: "bia@example.test").id)
    end

    it "with the web cookie, refuses a foreign origin" do
      sign_up(email: "bia@example.test", client: "web")

      delete "/api/v1/account", params: { password: IdentityHelpers::PASSWORD }, headers: { "Origin" => "https://evil.example" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Identity::AccountDeletion.count).to eq(0)
      expect_response_to_match_contract
    end

    it "wrong password is 401 and deletes nothing" do
      delete_account(password: "wrong password!")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_credentials")
      expect(Identity::AccountDeletion.count).to eq(0)
      expect(sessions_status(token)).to eq(200)
      expect_response_to_match_contract
    end

    it "a missing password is 401 too" do
      delete "/api/v1/account", params: {}, headers: bearer(token), as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(Identity::AccountDeletion.count).to eq(0)
      expect_response_to_match_contract
    end

    it "needs a session" do
      delete "/api/v1/account", params: { password: IdentityHelpers::PASSWORD }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect_response_to_match_contract
    end

    it "works without the health_data consent" do
      expect(Identity::Api.consent_granted?(user_id:, purpose: "health_data")).to be(false)

      delete_account

      expect(response).to have_http_status(:accepted)
    end

    it "limits attempts by IP: 10 in 3 minutes" do
      10.times { delete_account(password: "wrong password!") }
      delete_account

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("180")
      expect(Identity::AccountDeletion.count).to eq(0)
      expect_response_to_match_contract
    end

    it "limits attempts by account: 5 in 15 minutes, from any IP" do
      5.times { |n| delete_account(password: "wrong password!", env: { "REMOTE_ADDR" => "198.51.100.#{n}" }) }
      delete_account(env: { "REMOTE_ADDR" => "198.51.100.99" })

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("900")
      expect(Identity::AccountDeletion.count).to eq(0)
    end

    it "audits a wrong password as reauth_failed, without what was typed" do
      delete_account(password: "wrong password!")

      audit = Identity::AuditEvent.where(action: "reauth_failed").sole
      expect(audit.metadata).to eq({ "for" => "deletion" })
      expect(audit.attributes.values.join).not_to include("wrong password!")
    end

    it "never logs the password" do
      log_path = Rails.root.join("log/test.log")
      offset = File.size(log_path)
      level = Rails.logger.level
      Rails.logger.level = Logger::DEBUG

      delete_account

      Rails.logger.flush if Rails.logger.respond_to?(:flush)
      text = File.binread(log_path, nil, offset).force_encoding("UTF-8")
      expect(text).to include("/api/v1/account")
      expect(text).not_to include("ana@example.test", IdentityHelpers::PASSWORD, token)
    ensure
      Rails.logger.level = level
    end
  end
end
