require "rails_helper"
require "support/identity_helpers"

RSpec.describe "Cache-Control on authenticated responses", :identity do
  let!(:token) { mobile_token }

  before { Identity::Api.grant_consent(user_id: Identity::User.sole.id, purpose: "health_data", version: 1) }

  {
    "profile" => "/api/v1/profile",
    "sport profiles" => "/api/v1/sport_profiles",
    "consents" => "/api/v1/consents",
    "session list" => "/api/v1/sessions"
  }.each do |name, path|
    it "sends no-store on the #{name}" do
      get path, headers: bearer(token)

      expect(response.headers["Cache-Control"]).to eq("no-store")
    end
  end

  it "sends no-store on a 401 too" do
    get "/api/v1/profile"

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers["Cache-Control"]).to eq("no-store")
  end
end
