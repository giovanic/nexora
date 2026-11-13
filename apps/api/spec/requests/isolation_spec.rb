require "rails_helper"
require "support/identity_helpers"
require "support/outbox_helpers"

# AC-02-06: on every authenticated route, another person gets 404 or sees and
# changes nothing of mine. Routes with an id prove a 404 for someone else's id;
# routes without one prove that B acts and A's data stays as it was. The last
# example reads the Rails routes and fails when one has no case here.
RSpec.describe "isolation between people", :identity, :real_consumers do
  include OutboxHelpers

  ISOLATION_PUBLIC_CONTROLLERS = %w[api/v1/registrations api/v1/password_resets health].freeze
  # Sign in takes no session: nothing of anyone's to reach.
  ISOLATION_PUBLIC_ACTIONS = %w[sessions#create].freeze

  def self.authenticated_actions
    Rails.application.routes.routes.filter_map do |route|
      controller = route.defaults[:controller]
      next if route.verb.empty? || controller.nil? || !controller.start_with?("api/") || ISOLATION_PUBLIC_CONTROLLERS.include?(controller)

      action = "#{controller.delete_prefix('api/v1/')}##{route.defaults[:action]}"
      action unless ISOLATION_PUBLIC_ACTIONS.include?(action)
    end.uniq
  end

  let!(:a_token) { mobile_token(email: "ana@example.test") }
  let!(:b_token) { mobile_token(email: "bia@example.test") }
  let(:a_id) { Identity::User.find_by!(email: "ana@example.test").id }
  let(:b_id) { Identity::User.find_by!(email: "bia@example.test").id }
  let(:a_session_id) { Identity::Session.where(user_id: a_id).sole.id }
  let(:a_sport_id) { UserProfile::SportProfile.where(user_id: a_id).sole.id }
  let(:b_headers) { bearer(b_token) }

  before do
    allow(Identity::EraseAccountJob).to receive(:perform_async)
    [ a_token, b_token ].each do |token|
      post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
    end
    run_publisher
    patch "/api/v1/profile", params: { display_name: "Ana", motivations: %w[start_caring] }, headers: bearer(a_token), as: :json
    post "/api/v1/sport_profiles", params: { sport: "running", level: "beginner" }, headers: bearer(a_token), as: :json
    %w[usage_metrics food_photo_ai].each do |purpose|
      post "/api/v1/consents", params: { purpose:, version: 1 }, headers: bearer(a_token), as: :json
    end
    a_id
    b_id
  end

  # Everything of A's the routes could touch.
  def a_state
    {
      user: Identity::User.find(a_id).attributes,
      sessions: Identity::Session.where(user_id: a_id).order(:id).map(&:attributes),
      consents: Identity::ConsentRecord.where(user_id: a_id).order(:id).map(&:attributes),
      audits: Identity::AuditEvent.where(user_ref: a_id).order(:id).map(&:attributes),
      deletions: Identity::AccountDeletion.where(user_id: a_id).count,
      profile: UserProfile::Profile.find(a_id).attributes,
      sports: UserProfile::SportProfile.where(user_id: a_id).order(:id).map(&:attributes)
    }
  end

  def a_still_works
    get "/api/v1/sessions", headers: bearer(a_token)
    expect(response).to have_http_status(:ok)
    get "/api/v1/profile", headers: bearer(a_token)
    expect(response.parsed_body).to include("display_name" => "Ana")
  end

  ISOLATION_CASES = {
    "sessions#index" => lambda {
      get "/api/v1/sessions", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["sessions"].map { |s| s["id"] }).to eq([ Identity::Session.where(user_id: b_id).sole.id ])
      expect(response.body).not_to include(a_session_id)
    },
    "sessions#refresh" => lambda {
      post "/api/v1/sessions/refresh", headers: b_headers
      expect(response).to have_http_status(:ok)
    },
    "sessions#destroy" => lambda {
      delete "/api/v1/sessions/#{a_session_id}", headers: b_headers
      expect(response).to have_http_status(:not_found)
    },
    "sessions#destroy_current" => lambda {
      delete "/api/v1/sessions/current", headers: b_headers
      expect(response).to have_http_status(:no_content)
    },
    "consents#index" => lambda {
      get "/api/v1/consents", headers: b_headers
      expect(response).to have_http_status(:ok)
      mine = response.parsed_body["consents"].to_h { |consent| [ consent["purpose"], consent["state"] ] }
      expect(mine["health_data"]).to eq("granted")
      expect(mine["usage_metrics"]).not_to eq("granted")
    },
    "consents#create" => lambda {
      post "/api/v1/consents", params: { purpose: "food_photo_ai", version: 1 }, headers: b_headers, as: :json
      expect(response).to have_http_status(:created)
    },
    "consents#destroy" => lambda {
      post "/api/v1/consents", params: { purpose: "food_photo_ai", version: 1 }, headers: b_headers, as: :json
      delete "/api/v1/consents/food_photo_ai", headers: b_headers
      expect(response).to have_http_status(:no_content)
      expect(Identity::Api.consent_granted?(user_id: a_id, purpose: "food_photo_ai")).to be(true)
    },
    "consents#text" => lambda {
      get "/api/v1/consents/health_data/text", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to match_array(%w[purpose version text])
    },
    "profiles#show" => lambda {
      get "/api/v1/profile", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("display_name" => nil, "motivations" => [])
    },
    "profiles#update" => lambda {
      patch "/api/v1/profile", params: { display_name: "Bia", motivations: %w[track_progress] }, headers: b_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(UserProfile::Profile.find(b_id).display_name).to eq("Bia")
    },
    "sport_profiles#index" => lambda {
      get "/api/v1/sport_profiles", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["sport_profiles"]).to be_empty
    },
    "sport_profiles#create" => lambda {
      post "/api/v1/sport_profiles", params: { sport: "cycling", level: "advanced" }, headers: b_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(UserProfile::SportProfile.where(user_id: b_id).pluck(:sport)).to eq([ "cycling" ])
    },
    "sport_profiles#destroy" => lambda {
      delete "/api/v1/sport_profiles/#{a_sport_id}", headers: b_headers
      expect(response).to have_http_status(:not_found)
    },
    "accounts#export" => lambda {
      post "/api/v1/account/export", params: { password: IdentityHelpers::PASSWORD }, headers: b_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("ana@example.test", a_id, a_session_id, a_sport_id)
    },
    "accounts#destroy" => lambda {
      delete "/api/v1/account", params: { password: IdentityHelpers::PASSWORD }, headers: b_headers, as: :json
      expect(response).to have_http_status(:accepted)
      expect(Identity::AccountDeletion.pluck(:user_id)).to eq([ b_id ])
    }
  }.freeze

  ISOLATION_CASES.each do |action, scenario|
    it "#{action}: B acts and nothing of A's changes" do
      before = a_state

      instance_exec(&scenario)

      expect(a_state).to eq(before)
      a_still_works
    end
  end

  it "isolation: every authenticated route has a case where another person gets 404 and nothing changes" do
    routes = self.class.authenticated_actions

    expect(routes).not_to be_empty
    expect(routes - ISOLATION_CASES.keys).to be_empty, "authenticated route without an isolation case: #{(routes - ISOLATION_CASES.keys).join(', ')}"
    expect(ISOLATION_CASES.keys - routes).to be_empty, "case for a route that does not exist: #{(ISOLATION_CASES.keys - routes).join(', ')}"
  end
end
