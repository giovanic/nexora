require "rails_helper"
require "support/contract"
require "support/identity_helpers"

RSpec.describe "sessions", :identity do
  describe "POST /api/v1/sessions" do
    before { sign_up }

    it "mobile gets a token and no cookie" do
      sign_in(client: "mobile", device_label: "Tablet")

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["token"]).to be_present
      expect(response.headers["Set-Cookie"]).to be_blank
      expect_response_to_match_contract
    end

    it "web gets a __Host- cookie and no token in the body" do
      sign_in(client: "web")

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).not_to have_key("token")
      expect(session_cookie_header.downcase).to include("secure", "httponly", "samesite=lax", "path=/")
      expect_response_to_match_contract
    end

    it "treats \" Ana@X.com \" as ana@x.com" do
      sign_up(email: " Ana@X.com ")
      sign_in(email: "ana@x.com")

      expect(response).to have_http_status(:created)
    end

    it "same message for unknown email and wrong password" do
      sign_in(password: "wrong password!")
      wrong_password = response.parsed_body["error"].except("request_id")
      expect(response).to have_http_status(:unauthorized)
      expect_response_to_match_contract

      sign_in(email: "nobody@example.test")

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"].except("request_id")).to eq(wrong_password)
      expect(wrong_password["code"]).to eq("invalid_credentials")
    end

    it "audit records a failed sign in without the typed email" do
      sign_in(email: "typed@example.test", password: "wrong password!")

      audit = Identity::AuditEvent.find_by!(action: "sign_in_failed")
      expect(audit).to have_attributes(user_ref: nil, metadata: {})
      expect(audit.ip_hmac).to be_present
      expect(Identity::AuditEvent.connection.select_all("SELECT * FROM audit_events").to_a.to_s).not_to include("typed")
    end

    it "refuses an unknown client before checking the password" do
      sign_in(client: "desktop")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include({ "field" => "client", "code" => "inclusion" })
      expect_response_to_match_contract
    end

    describe "rate limit answers 429 with Retry-After" do
      it "allows 10 sign ins per IP in 3 minutes" do
        10.times { |n| sign_in(email: "person#{n}@example.test") }
        sign_in

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers["Retry-After"]).to eq("180")
        expect_response_to_match_contract
      end

      it "allows 5 sign ins per normalized e-mail in 15 minutes, from any IP" do
        5.times { |n| sign_in(email: " ANA@example.test", password: "wrong password!", env: { "REMOTE_ADDR" => "198.51.100.#{n}" }) }
        sign_in(env: { "REMOTE_ADDR" => "198.51.100.99" })

        expect(response).to have_http_status(:too_many_requests)
        expect(response.headers["Retry-After"]).to eq("900")
      end
    end

    it "keeps e-mail, password and token out of the log" do
      log_path = Rails.root.join("log/test.log")
      offset = File.size(log_path)

      sign_in(email: "ana@example.test", password: IdentityHelpers::PASSWORD)
      token = response.parsed_body["token"]
      sign_in(email: "ana@example.test", password: "wrong password!")
      post "/api/v1/sessions/refresh", headers: bearer(token)

      Rails.logger.flush if Rails.logger.respond_to?(:flush)
      text = File.binread(log_path, nil, offset).force_encoding("UTF-8")
      expect(text).to include("/api/v1/sessions")
      expect(text).not_to include("ana@example.test", IdentityHelpers::PASSWORD, "wrong password!", token)
    end
  end

  describe "GET /api/v1/sessions" do
    it "lists the person's own sessions and marks the current one" do
      mobile_token(email: "bia@example.test")
      token = mobile_token
      sign_in(client: "web")

      get "/api/v1/sessions", headers: bearer(token)

      expect(response).to have_http_status(:ok)
      sessions = response.parsed_body["sessions"]
      expect(sessions.map { |session| session["client"] }).to contain_exactly("mobile", "web")
      expect(sessions.find { |session| session["current"] }).to include("client" => "mobile", "device_label" => "Pixel 8")
      expect_response_to_match_contract
    end

    it "accepts the web cookie on a read without Origin" do
      sign_up(client: "web")

      get "/api/v1/sessions"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["sessions"].sole).to include("client" => "web", "current" => true)
    end

    it "answers 401 without a session" do
      get "/api/v1/sessions"

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("unauthorized")
      expect_response_to_match_contract
    end

    it "revoked and expired sessions get 401" do
      token = mobile_token
      other = mobile_token(email: "bia@example.test")

      delete "/api/v1/sessions/current", headers: bearer(token)
      get "/api/v1/sessions", headers: bearer(token)
      expect(response).to have_http_status(:unauthorized)

      travel_to(30.days.from_now + 1.second) do
        get "/api/v1/sessions", headers: bearer(other)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    it "idle and absolute expiry" do
      start = Time.current
      token = mobile_token

      [ 29, 58, 87 ].each do |day|
        travel_to(start + day.days) do
          get "/api/v1/sessions", headers: bearer(token)
          expect(response).to have_http_status(:ok)
        end
      end

      travel_to(start + 90.days + 1.second) do
        get "/api/v1/sessions", headers: bearer(token)

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/sessions/refresh" do
    it "gives mobile a new token and ends the old one" do
      token = mobile_token

      post "/api/v1/sessions/refresh", headers: bearer(token)

      expect(response).to have_http_status(:ok)
      new_token = response.parsed_body.fetch("token")
      expect(new_token).not_to eq(token)
      expect_response_to_match_contract

      get "/api/v1/sessions", headers: bearer(token)
      expect(response).to have_http_status(:unauthorized)
      get "/api/v1/sessions", headers: bearer(new_token)
      expect(response).to have_http_status(:ok)
    end

    it "gives web a new cookie and no token" do
      sign_up(client: "web")
      old_cookie = session_cookie_header

      post "/api/v1/sessions/refresh", headers: { "Origin" => IdentityHelpers::WEB_ORIGIN }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).not_to have_key("token")
      expect(session_cookie_header).to be_present
      expect(session_cookie_header).not_to eq(old_cookie)
      expect_response_to_match_contract
    end

    it "answers 401 for a revoked token" do
      token = mobile_token
      post "/api/v1/sessions/refresh", headers: bearer(token)

      post "/api/v1/sessions/refresh", headers: bearer(token)

      expect(response).to have_http_status(:unauthorized)
      expect_response_to_match_contract
    end

    it "limits refresh by IP only: 10 in 3 minutes" do
      token = mobile_token
      10.times do
        post "/api/v1/sessions/refresh", headers: bearer(token)
        token = response.parsed_body["token"]
      end
      expect(response).to have_http_status(:ok)

      post "/api/v1/sessions/refresh", headers: bearer(token)

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("180")
    end

    context "with two requests at once, on the real database" do
      self.use_transactional_tests = false

      after do
        [ Identity::AuditEvent, Identity::Session, Shared::Outbox::Event, Identity::User ].each(&:delete_all)
      end

      it "concurrent refresh: one wins, the other gets 401" do
        token = mobile_token
        # Holds the first refresh inside its transaction, so the second one
        # arrives while the row is still locked.
        allow_any_instance_of(Identity::Session).to receive(:revoke!).and_wrap_original do |original, *arguments|
          sleep 0.3
          original.call(*arguments)
        end

        clients = Array.new(2) { open_session.tap(&:https!) }
        statuses = clients.map do |client|
          Thread.new do
            client.post "/api/v1/sessions/refresh", headers: bearer(token)
            client.response.status
          end
        end.map(&:value)

        expect(statuses).to contain_exactly(200, 401)
        expect(Identity::Session.where(revoked_at: nil).count).to eq(1)
      end
    end
  end

  describe "DELETE /api/v1/sessions/current" do
    it "signs out and clears the web cookie" do
      sign_up(client: "web")

      delete "/api/v1/sessions/current", headers: { "Origin" => IdentityHelpers::WEB_ORIGIN }

      expect(response).to have_http_status(:no_content)
      expect(session_cookie_header).to match(/max-age=0|expires=Thu, 01 Jan 1970/i)
      expect(Identity::Session.sole.revoked_at).to be_present
      expect_response_to_match_contract
    end

    it "cookie request with a foreign Origin is refused" do
      sign_up(client: "web")

      delete "/api/v1/sessions/current", headers: { "Origin" => "https://evil.example" }

      expect(response).to have_http_status(:forbidden)
      expect(Identity::Session.sole.revoked_at).to be_nil
      expect_response_to_match_contract
    end

    it "refuses a cookie request that changes state without Origin" do
      sign_up(client: "web")

      post "/api/v1/sessions/refresh"

      expect(response).to have_http_status(:forbidden)
      expect(Identity::Session.where(revoked_at: nil).count).to eq(1)
    end

    it "does not ask a Bearer request for an Origin" do
      token = mobile_token

      delete "/api/v1/sessions/current", headers: bearer(token).merge("Origin" => "https://evil.example")

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "DELETE /api/v1/sessions/{id}" do
    it "signs another device of the same person out" do
      token = mobile_token
      sign_in(client: "mobile", device_label: "Tablet")
      tablet = Identity::Session.find_by!(device_label: "Tablet")

      delete "/api/v1/sessions/#{tablet.id}", headers: bearer(token)

      expect(response).to have_http_status(:no_content)
      expect(tablet.reload.revoked_at).to be_present
      expect_response_to_match_contract
    end

    it "answers 404 for another person's session" do
      token = mobile_token
      mobile_token(email: "bia@example.test")
      bia_session = Identity::User.find_by!(email: "bia@example.test").sessions.sole

      delete "/api/v1/sessions/#{bia_session.id}", headers: bearer(token)

      expect(response).to have_http_status(:not_found)
      expect(bia_session.reload.revoked_at).to be_nil
      expect_response_to_match_contract
    end

    it "answers 404 for an id that is not a UUID" do
      delete "/api/v1/sessions/abc", headers: bearer(mobile_token)

      expect(response).to have_http_status(:not_found)
    end

    it "answers 401 without a session" do
      delete "/api/v1/sessions/#{SecureRandom.uuid}"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
