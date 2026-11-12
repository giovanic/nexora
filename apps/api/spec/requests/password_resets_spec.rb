require "rails_helper"
require "support/contract"
require "support/identity_helpers"

RSpec.describe "password resets", :identity do
  let(:new_password) { "a brand new passphrase" }

  # The delivery job runs right away, so each example reads the mail it sent.
  before do
    ActionMailer::Base.deliveries.clear
    allow(Identity::PasswordResetJob).to receive(:perform_async) { |user_id| Identity::PasswordResetJob.new.perform(user_id) }
  end

  def request_reset(email = "ana@example.test", env: {})
    post "/api/v1/password_resets", params: { email: }, env:, as: :json
  end

  def reset(token, password: new_password, env: {})
    patch "/api/v1/password_resets/#{token}", params: { password: }, env:, as: :json
  end

  def mailed_link
    ActionMailer::Base.deliveries.last.body.to_s[%r{\S+/reset-password#token=\S+}]
  end

  def mailed_token
    mailed_link[/#token=(\S+)\z/, 1]
  end

  describe "POST /api/v1/password_resets" do
    before { sign_up }

    it "answers 202 for unknown and known emails" do
      request_reset(" ANA@example.test ")

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
      expect_response_to_match_contract
      expect(ActionMailer::Base.deliveries.sole.to).to eq([ "ana@example.test" ])

      request_reset("nobody@example.test")

      expect(response).to have_http_status(:accepted)
      expect(response.body).to be_empty
      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end

    it "does the same work for unknown and known emails, so the timing matches" do
      request_reset("nobody@example.test")
      request_reset

      expect(Identity::PasswordResetJob).to have_received(:perform_async).twice
      expect(Identity::PasswordResetJob).to have_received(:perform_async).with(nil).once
      expect(Identity::PasswordResetJob).to have_received(:perform_async).with(Identity::User.sole.id).once
    end

    it "gives the job only the user id, never the email or the token" do
      request_reset

      expect(Identity::PasswordResetJob).to have_received(:perform_async).with(Identity::User.sole.id)
    end

    it "sends nothing for an account that was deleted" do
      Identity::User.sole.update_columns(deleted_at: Time.current)

      request_reset

      expect(response).to have_http_status(:accepted)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "answers 202 for a body without a usable email" do
      post "/api/v1/password_resets", params: { email: [ "ana@example.test" ] }, as: :json

      expect(response).to have_http_status(:accepted)
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "link uses the fragment and APP_WEB_URL" do
      allow(Rails.configuration.x).to receive(:app_web_url).and_return("https://app.example.test")

      request_reset

      mail = ActionMailer::Base.deliveries.sole
      expect(mailed_link).to start_with("https://app.example.test/reset-password#token=")
      expect(mail.body.to_s).not_to include("?token")
      expect(mail.subject).to eq("Redefinir sua senha")
      expect(mail.body.to_s).to include("15 minutos")
    end

    it "makes a token that needs no escaping in a URL" do
      request_reset

      expect(mailed_token).to match(/\A[A-Za-z0-9_-]+(--[A-Za-z0-9_-]+)?\z/)
    end

    describe "rate limit answers 429 with Retry-After" do
      it "allows 10 requests per IP in 3 minutes" do
        10.times { |n| request_reset("person#{n}@example.test") }
        request_reset

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers["Retry-After"]).to eq("180")
        expect_response_to_match_contract
      end

      it "allows 5 requests per normalized e-mail in 15 minutes, from any IP" do
        5.times { |n| request_reset(" ANA@example.test", env: { "REMOTE_ADDR" => "198.51.100.#{n}" }) }
        request_reset(env: { "REMOTE_ADDR" => "198.51.100.99" })

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers["Retry-After"]).to eq("900")
        expect(ActionMailer::Base.deliveries.size).to eq(5)
      end
    end
  end

  describe "PATCH /api/v1/password_resets/{token}" do
    before do
      sign_up
      request_reset
    end

    it "token works once" do
      token = mailed_token

      reset(token)

      expect(response).to have_http_status(:no_content)
      expect_response_to_match_contract

      reset(token, password: "yet another passphrase")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
      expect_response_to_match_contract
      sign_in(password: new_password)
      expect(response).to have_http_status(:created)
    end

    it "token expires after 15 minutes" do
      token = mailed_token

      travel 15.minutes + 1.second do
        reset(token)
      end

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
      sign_in
      expect(response).to have_http_status(:created)
    end

    it "accepts the token just before 15 minutes" do
      token = mailed_token

      travel 14.minutes + 50.seconds do
        reset(token)
      end

      expect(response).to have_http_status(:no_content)
    end

    it "reset revokes every session" do
      tokens = Array.new(2) do
        sign_in
        response.parsed_body.fetch("token")
      end

      reset(mailed_token)

      expect(response).to have_http_status(:no_content)
      expect(Identity::Session.where(revoked_at: nil)).to be_empty
      tokens.each do |token|
        get "/api/v1/sessions", headers: bearer(token)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "does not sign in after the reset" do
      reset(mailed_token)

      expect(response.body).to be_empty
      expect(session_cookie_header).to be_nil
      expect(Identity::Session.where(revoked_at: nil)).to be_empty
    end

    it "the old password stops working" do
      reset(mailed_token)

      sign_in

      expect(response).to have_http_status(:unauthorized)
    end

    it "audits the reset without the email or the token" do
      token = mailed_token

      reset(token)

      audit = Identity::AuditEvent.find_by!(action: "password_reset")
      expect(audit).to have_attributes(user_ref: Identity::User.sole.id, metadata: {})
      expect(audit.ip_hmac).to be_present
      expect(Identity::AuditEvent.connection.select_all("SELECT * FROM audit_events").to_a.to_s).not_to include("ana@", token)
    end

    it "answers invalid_token for a made-up or tampered token" do
      [ "not-a-token", "#{mailed_token}x", "a.b" ].each do |token|
        reset(token)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("error", "code")).to eq("invalid_token")
      end
    end

    it "refuses a short password and keeps the token usable" do
      token = mailed_token

      reset(token, password: "short")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include({ "field" => "password", "code" => "too_short" })
      expect_response_to_match_contract

      reset(token)
      expect(response).to have_http_status(:no_content)
    end

    it "limits attempts by IP: 10 in 3 minutes" do
      10.times { reset("not-a-token") }
      reset(mailed_token)

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("180")
      expect_response_to_match_contract
    end
  end

  it "logs never contain the token" do
    log_path = Rails.root.join("log/test.log")
    offset = File.size(log_path)
    # The most verbose level, where Action Mailer would print the whole message.
    level = Rails.logger.level
    Rails.logger.level = :debug

    sign_up
    request_reset
    link = mailed_link
    token = mailed_token
    reset(token)
    reset(token)
    request_reset("nobody@example.test")

    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    text = File.binread(log_path, nil, offset).force_encoding("UTF-8")
    expect(text).to include("/api/v1/password_resets")
    expect(text).not_to include(token, link, "reset-password", "ana@example.test", "nobody@example.test", new_password)
  ensure
    Rails.logger.level = level
  end

  context "with two resets at once, on the real database" do
    self.use_transactional_tests = false

    after do
      [ Identity::AuditEvent, Identity::Session, Shared::Outbox::Event, Identity::User ].each(&:delete_all)
    end

    it "only one of two concurrent resets with the same token wins" do
      sign_up
      request_reset
      token = mailed_token
      # Holds the first reset inside its transaction, so the second one
      # arrives while the row is still locked.
      allow_any_instance_of(Identity::User).to receive(:save!).and_wrap_original do |original, *arguments|
        sleep 0.3
        original.call(*arguments)
      end

      clients = Array.new(2) { open_session.tap(&:https!) }
      statuses = clients.zip([ new_password, "yet another passphrase" ]).map do |client, password|
        Thread.new do
          client.patch "/api/v1/password_resets/#{token}", params: { password: }, as: :json
          client.response.status
        end
      end.map(&:value)

      expect(statuses).to contain_exactly(204, 422)
      expect(Identity::AuditEvent.where(action: "password_reset").count).to eq(1)
    end
  end
end
