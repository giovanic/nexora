require "rails_helper"
require "support/contract"
require "support/identity_helpers"

RSpec.describe "consents", :identity do
  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.sole.id }

  def grant(purpose:, version: 1, headers: bearer(token))
    post "/api/v1/consents", params: { purpose:, version: }, headers:, as: :json
  end

  describe "GET /api/v1/consents" do
    it "lists every purpose with its state" do
      grant(purpose: "health_data")

      get "/api/v1/consents", headers: bearer(token)

      expect(response).to have_http_status(:ok)
      consents = response.parsed_body.fetch("consents").index_by { |consent| consent["purpose"] }
      expect(consents.keys).to eq(%w[health_data food_photo_ai strava_integration usage_metrics])
      expect(consents["health_data"]).to include("state" => "granted", "current_version" => 1, "accepted_version" => 1)
      expect(consents["food_photo_ai"]).to include("state" => "pending", "accepted_version" => nil, "decided_at" => nil)
      expect_response_to_match_contract
    end

    it "lists the consent as outdated when the text in force changed after the grant" do
      grant(purpose: "health_data")
      stub_const("Identity::ConsentTexts::CURRENT_VERSIONS", Identity::ConsentTexts::CURRENT_VERSIONS.merge("health_data" => 2))

      get "/api/v1/consents", headers: bearer(token)

      consent = response.parsed_body.fetch("consents").find { |item| item["purpose"] == "health_data" }
      expect(consent).to include("state" => "outdated", "accepted_version" => 1, "current_version" => 2)
      expect_response_to_match_contract
    end

    it "shows only the signed-in person's consents" do
      grant(purpose: "usage_metrics")
      other = mobile_token(email: "bia@example.test")

      get "/api/v1/consents", headers: bearer(other)

      expect(response.parsed_body.fetch("consents").map { |consent| consent["state"] }.uniq).to eq([ "pending" ])
    end

    it "needs a session" do
      get "/api/v1/consents"

      expect(response).to have_http_status(:unauthorized)
      expect_response_to_match_contract
    end
  end

  describe "POST /api/v1/consents" do
    it "grants the current version, recording the client" do
      grant(purpose: "health_data")

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("purpose" => "health_data", "state" => "granted", "accepted_version" => 1)
      expect(Identity::ConsentRecord.sole).to have_attributes(user_id:, action: "granted", text_version: 1, source: "mobile")
      expect_response_to_match_contract
    end

    it "outdated version is refused with 409 outdated_version" do
      grant(purpose: "health_data", version: 2)

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("error", "code")).to eq("outdated_version")
      expect(Identity::ConsentRecord.count).to eq(0)
      expect_response_to_match_contract
    end

    it "refuses an unknown purpose with 422" do
      grant(purpose: "marketing")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "purpose", "code" => "inclusion" } ])
      expect_response_to_match_contract
    end

    it "needs an allowed Origin on the web" do
      sign_in(client: "web")
      cookie = session_cookie_header.split(";").first

      grant(purpose: "health_data", headers: { "Cookie" => cookie, "Origin" => "https://evil.example" })

      expect(response).to have_http_status(:forbidden)
      expect(Identity::ConsentRecord.count).to eq(0)
    end
  end

  describe "DELETE /api/v1/consents/{purpose}" do
    it "revokes a purpose and keeps the history" do
      grant(purpose: "strava_integration")

      delete "/api/v1/consents/strava_integration", headers: bearer(token)

      expect(response).to have_http_status(:no_content)
      expect(Identity::ConsentRecord.order(:occurred_at).pluck(:action)).to eq(%w[granted revoked])
    end

    it "revoking health_data revokes like any other purpose" do
      grant(purpose: "health_data")

      delete "/api/v1/consents/health_data", headers: bearer(token)

      expect(response).to have_http_status(:no_content)
      expect(Identity::Api.consent_granted?(user_id:, purpose: "health_data")).to be(false)
      expect(Identity::ConsentRecord.where(purpose: "health_data").order(:occurred_at).pluck(:action)).to eq(%w[granted revoked])
    end

    it "answers 404 for an unknown purpose" do
      delete "/api/v1/consents/marketing", headers: bearer(token)

      expect(response).to have_http_status(:not_found)
      expect_response_to_match_contract
    end
  end

  describe "GET /api/v1/consents/{purpose}/text" do
    it "texts are served from config/consents" do
      get "/api/v1/consents/health_data/text", headers: bearer(token)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "purpose" => "health_data", "version" => 1, "text" => Rails.root.join("config/consents/health_data.v1.md").read
      )
      expect_response_to_match_contract
    end

    it "answers 404 for an unknown purpose" do
      get "/api/v1/consents/marketing/text", headers: bearer(token)

      expect(response).to have_http_status(:not_found)
      expect_response_to_match_contract
    end
  end

  describe "require_consent :health_data" do
    # A test-only controller, since the profile routes that use the filter come in Task 6.
    let(:controller_class) do
      Class.new(ApplicationController) do
        require_consent :health_data

        def show = render(json: { ok: true })

        def self.name = "ConsentProbeController"
      end
    end

    # The routes are swapped below, so the account is opened through the Api.
    let!(:token) do
      body = registration_body.slice(:email, :password, :adult_confirmed, :time_zone, :client, :device_label)
      Identity::Api.register(**body, ip: nil).session_token
    end

    before { stub_const("ConsentProbeController", controller_class) }

    around do |example|
      with_routing do |routes|
        routes.draw { get "/consent_probe", to: "consent_probe#show" }
        example.run
      end
    end

    it "answers 403 consent_required without health_data" do
      get "/consent_probe", headers: bearer(token)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
    end

    it "lets the request through once health_data is granted" do
      Identity::Api.grant_consent(user_id:, purpose: "health_data", version: 1)

      get "/consent_probe", headers: bearer(token)

      expect(response).to have_http_status(:ok)
    end

    describe "when the text in force changes after the grant" do
      before do
        Identity::Api.grant_consent(user_id:, purpose: "health_data", version: 1)
        stub_const("Identity::ConsentTexts::CURRENT_VERSIONS", Identity::ConsentTexts::CURRENT_VERSIONS.merge("health_data" => 2))
      end

      it "no longer counts the old grant" do
        expect(Identity::Api.consent_granted?(user_id:, purpose: "health_data")).to be(false)
      end

      it "answers 403 consent_required on a health_data route" do
        get "/consent_probe", headers: bearer(token)

        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
      end
    end

    it "answers 401 before checking the consent when there is no session" do
      get "/consent_probe"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
