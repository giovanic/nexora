require "rails_helper"
require "support/identity_helpers"
require "support/outbox_helpers"

# AC-02-06: on every authenticated route, another person gets 404 or sees and
# changes nothing of mine. Routes with an id prove a 404 for someone else's id;
# routes without one prove that B acts and A's data stays as it was. The last
# example reads the Rails routes and fails when one has no case here.
RSpec.describe "isolation between people", :identity, :real_consumers do
  include OutboxHelpers

  # Routes that take no session, by "VERB path". Anything else under api/ needs a case.
  ISOLATION_PUBLIC_ROUTES = [
    "POST /api/v1/registrations", "POST /api/v1/sessions", # sign up and sign in
    "POST /api/v1/password_resets", "PATCH /api/v1/password_resets/:token"
  ].freeze
  # Outside api/ only these controller#action pairs may exist: health probes,
  # local-only operational probes (internal_routes_spec) and Rails development tools.
  ISOLATION_OTHER_ACTIONS = %w[
    health#live health#ready
    internal/smoke_jobs#create internal/smoke_jobs#show internal/smoke_errors#create
    rails/welcome#index rails/info#index rails/info#properties rails/info#routes rails/info#notes
    rails/mailers#index rails/mailers#download rails/mailers#preview
  ].freeze

  # Returns the "VERB path" of every route that needs a case, and the routes
  # outside api/ that are on no list.
  def self.classify_routes
    needing_case = []
    unknown = []
    Rails.application.routes.routes.each do |route|
      next if route.verb.empty?

      controller = route.defaults[:controller].to_s
      key = "#{route.verb} #{route.path.spec.to_s.delete_suffix('(.:format)')}"
      if controller.start_with?("api/")
        needing_case << key unless ISOLATION_PUBLIC_ROUTES.include?(key)
      elsif !ISOLATION_OTHER_ACTIONS.include?("#{controller}##{route.defaults[:action]}")
        unknown << "#{key} (#{controller}##{route.defaults[:action]})"
      end
    end
    [ needing_case, unknown ]
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
    "GET /api/v1/sessions" => lambda {
      get "/api/v1/sessions", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["sessions"].map { |s| s["id"] }).to eq([ Identity::Session.where(user_id: b_id).sole.id ])
      expect(response.body).not_to include(a_session_id)
    },
    "POST /api/v1/sessions/refresh" => lambda {
      post "/api/v1/sessions/refresh", headers: b_headers
      expect(response).to have_http_status(:ok)
    },
    "DELETE /api/v1/sessions/:id" => lambda {
      delete "/api/v1/sessions/#{a_session_id}", headers: b_headers
      expect(response).to have_http_status(:not_found)
    },
    "DELETE /api/v1/sessions/current" => lambda {
      delete "/api/v1/sessions/current", headers: b_headers
      expect(response).to have_http_status(:no_content)
    },
    "GET /api/v1/consents" => lambda {
      get "/api/v1/consents", headers: b_headers
      expect(response).to have_http_status(:ok)
      mine = response.parsed_body["consents"].to_h { |consent| [ consent["purpose"], consent["state"] ] }
      expect(mine["health_data"]).to eq("granted")
      expect(mine["usage_metrics"]).not_to eq("granted")
    },
    "POST /api/v1/consents" => lambda {
      post "/api/v1/consents", params: { purpose: "food_photo_ai", version: 1 }, headers: b_headers, as: :json
      expect(response).to have_http_status(:created)
    },
    "DELETE /api/v1/consents/:purpose" => lambda {
      post "/api/v1/consents", params: { purpose: "food_photo_ai", version: 1 }, headers: b_headers, as: :json
      delete "/api/v1/consents/food_photo_ai", headers: b_headers
      expect(response).to have_http_status(:no_content)
      expect(Identity::Api.consent_granted?(user_id: a_id, purpose: "food_photo_ai")).to be(true)
    },
    "GET /api/v1/consents/:purpose/text" => lambda {
      get "/api/v1/consents/health_data/text", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to match_array(%w[purpose version text])
    },
    "GET /api/v1/profile" => lambda {
      get "/api/v1/profile", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("display_name" => nil, "motivations" => [])
    },
    "PATCH /api/v1/profile" => lambda {
      patch "/api/v1/profile", params: { display_name: "Bia", motivations: %w[track_progress] }, headers: b_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(UserProfile::Profile.find(b_id).display_name).to eq("Bia")
    },
    "GET /api/v1/sport_profiles" => lambda {
      get "/api/v1/sport_profiles", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["sport_profiles"]).to be_empty
    },
    "POST /api/v1/sport_profiles" => lambda {
      post "/api/v1/sport_profiles", params: { sport: "cycling", level: "advanced" }, headers: b_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(UserProfile::SportProfile.where(user_id: b_id).pluck(:sport)).to eq([ "cycling" ])
    },
    "DELETE /api/v1/sport_profiles/:id" => lambda {
      delete "/api/v1/sport_profiles/#{a_sport_id}", headers: b_headers
      expect(response).to have_http_status(:not_found)
    },
    "POST /api/v1/account/export" => lambda {
      post "/api/v1/account/export", params: { password: IdentityHelpers::PASSWORD }, headers: b_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("ana@example.test", a_id, a_session_id, a_sport_id)
    },
    # The real erasure runs for B, with A's consumers and erasers registered.
    "DELETE /api/v1/account" => lambda {
      delete "/api/v1/account", params: { password: IdentityHelpers::PASSWORD }, headers: b_headers, as: :json
      expect(response).to have_http_status(:accepted)
      expect(Identity::AccountDeletion.pluck(:user_id)).to eq([ b_id ])
      run_publisher
      Identity::EraseAccountJob.new.perform(Identity::AccountDeletion.sole.id)
      expect(Identity::AccountDeletion.sole.completed_at).to be_present
      expect(Identity::User.find(b_id).deleted_at).to be_present
      expect(UserProfile::Profile.find_by(user_id: b_id)).to be_nil
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
    routes, unknown = self.class.classify_routes

    expect(routes).not_to be_empty
    expect(unknown).to be_empty, "route outside api/ on no list: #{unknown.join(', ')}"
    expect(routes - ISOLATION_CASES.keys).to be_empty, "authenticated route without an isolation case: #{(routes - ISOLATION_CASES.keys).join(', ')}"
    expect(ISOLATION_CASES.keys - routes).to be_empty, "case for a route that does not exist: #{(ISOLATION_CASES.keys - routes).join(', ')}"
  end
end
