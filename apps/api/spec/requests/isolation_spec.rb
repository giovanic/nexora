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
      sports: UserProfile::SportProfile.where(user_id: a_id).order(:id).map(&:attributes),
      meals: Nutrition::FoodEntry.where(user_id: a_id).order(:id).map(&:attributes),
      meal_items: Nutrition::FoodItem.where(food_entry_id: Nutrition::FoodEntry.where(user_id: a_id).select(:id)).order(:id).map(&:attributes),
      photos: FoodAi::FoodPhoto.where(user_id: a_id).count,
      goals: Goals::Goal.where(user_id: a_id).order(:id).map(&:attributes),
      goal_check_ins: Goals::GoalCheckIn.where(user_id: a_id).order(:id).map(&:attributes)
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
    # The catalog is shared reference data: B's search reads it and writes nothing of A's.
    "POST /api/v1/foods/search" => lambda {
      post "/api/v1/foods/search", params: { term: "arroz" }, headers: b_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to eq(%w[items next_page])
    },
    # B has no food_photo_ai consent, so the upload is refused and starts nothing; A has no meal or photo.
    "POST /api/v1/food_entries/uploads" => lambda {
      post "/api/v1/food_entries/uploads", params: { client_request_id: "req-1", content_type: "image/jpeg", byte_size: 1000, meal_at: Time.current.iso8601 },
                                           headers: b_headers, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(Nutrition::FoodEntry.count + FoodAi::FoodPhoto.count).to eq(0)
    },
    # A's meal has its photo in storage; B asks to analyze it and gets 404, and the meal stays pending.
    # A's meal is analyzed with an item; B asks for it and gets 404, with no body of A's.
    "GET /api/v1/food_entries/:id" => lambda {
      entry = Nutrition::FoodEntry.find_by!(user_id: a_id)

      get "/api/v1/food_entries/#{entry.id}", headers: b_headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include(entry.id, a_id)
    },
    "POST /api/v1/food_entries/:id/analysis" => lambda {
      entry = Nutrition::FoodEntry.find_by!(user_id: a_id)
      photo = FoodAi::FoodPhoto.find(entry.photo_id)
      allow(FoodAi::AnalyzeJob).to receive(:perform_async)

      post "/api/v1/food_entries/#{entry.id}/analysis", headers: b_headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(entry.reload.status).to eq("pending")
      expect(photo.reload.status).to eq("awaiting_upload")
      expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
    },
    # A's meal is analyzed with an item: B confirms, edits, removes and deletes it and gets 404, with no body of A's.
    "POST /api/v1/food_entries/:id/confirmation" => lambda {
      post "/api/v1/food_entries/#{a_analyzed.id}/confirmation", headers: b_headers, as: :json
      expect(response).to have_http_status(:not_found)
    },
    "POST /api/v1/food_entries/:id/items" => lambda {
      post "/api/v1/food_entries/#{a_analyzed.id}/items", params: { free_text_name: "x", grams_likely: 10 }, headers: b_headers, as: :json
      expect(response).to have_http_status(:not_found)
    },
    "PATCH /api/v1/food_entries/:id/items/:item_id" => lambda {
      patch "/api/v1/food_entries/#{a_analyzed.id}/items/#{a_item.id}", params: { grams_likely: 10 }, headers: b_headers, as: :json
      expect(response).to have_http_status(:not_found)
    },
    "DELETE /api/v1/food_entries/:id/items/:item_id" => lambda {
      delete "/api/v1/food_entries/#{a_analyzed.id}/items/#{a_item.id}", headers: b_headers, as: :json
      expect(response).to have_http_status(:not_found)
    },
    "DELETE /api/v1/food_entries/:id" => lambda {
      delete "/api/v1/food_entries/#{a_analyzed.id}", headers: b_headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(FoodAi.storage.head(key: FoodAi::FoodPhoto.find(a_analyzed.photo_id).object_key)).to be_present
    },
    # B's history is B's: A's meal is not in it. B's manual meal is B's and changes nothing of A's.
    "GET /api/v1/food_entries" => lambda {
      get "/api/v1/food_entries", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["items"]).to eq([])
      expect(response.body).not_to include(a_analyzed.id)
    },
    "POST /api/v1/food_entries" => lambda {
      post "/api/v1/food_entries", params: { client_request_id: "a-req", meal_at: Time.current.iso8601, items: [ { free_text_name: "x", grams_likely: 10 } ] },
                                   headers: b_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(Nutrition::FoodEntry.where(user_id: b_id).count).to eq(1)
    },
    # B's goal types, list and history are B's: A's goal is in none of them.
    "GET /api/v1/goal_types" => lambda {
      get "/api/v1/goal_types", headers: b_headers
      expect(response).to have_http_status(:ok)
    },
    "GET /api/v1/goals" => lambda {
      get "/api/v1/goals", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["goals"]).to eq([])
      expect(response.body).not_to include(a_goal.id)
    },
    "POST /api/v1/goals" => lambda {
      post "/api/v1/goals", params: { goal_type: "drink_water" }, headers: b_headers, as: :json
      expect(response).to have_http_status(:created)
      expect(response.parsed_body["id"]).not_to eq(a_goal.id)
      expect(Goals::Goal.where(user_id: b_id).count).to eq(1)
    },
    "GET /api/v1/goals/:id" => lambda {
      get "/api/v1/goals/#{a_goal.id}", headers: b_headers
      expect(response).to have_http_status(:not_found)
    },
    "PATCH /api/v1/goals/:id" => lambda {
      patch "/api/v1/goals/#{a_goal.id}", params: { status: "paused" }, headers: b_headers, as: :json
      expect(response).to have_http_status(:not_found)
    },
    "DELETE /api/v1/goals/:id" => lambda {
      delete "/api/v1/goals/#{a_goal.id}", headers: b_headers
      expect(response).to have_http_status(:not_found)
    },
    "POST /api/v1/goals/:id/check_ins" => lambda {
      post "/api/v1/goals/#{a_goal.id}/check_ins", params: { local_date: Date.current.to_s }, headers: b_headers, as: :json
      expect(response).to have_http_status(:not_found)
    },
    "DELETE /api/v1/goals/:id/check_ins/:local_date" => lambda {
      delete "/api/v1/goals/#{a_goal.id}/check_ins/#{Date.current}", headers: b_headers
      expect(response).to have_http_status(:not_found)
    },
    "GET /api/v1/goals/history" => lambda {
      get "/api/v1/goals/history", headers: b_headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["items"]).to eq([])
      get "/api/v1/goals/history", params: { goal_id: a_goal.id }, headers: b_headers
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

  # A's meal and photo for the cases that need them, made before the state is taken.
  def a_meal
    entry = Nutrition::FoodEntry.create!(user_id: a_id, client_request_id: "a-req", meal_at: Time.current, local_date: Date.current, status: "pending")
    photo = FoodAi::FoodPhoto.create!(user_id: a_id, food_entry_id: entry.id, client_request_id: "a-req", object_key: "food-photos/#{SecureRandom.uuid}",
                                      content_type: "image/jpeg", byte_size: 3, authorized_at: Time.current)
    entry.update!(photo_id: photo.id)
    FoodAi.storage.write(key: photo.object_key, bytes: "abc", content_type: "image/jpeg")
    entry
  end

  # A's analyzed meal with an item and its photo, for the routes that change or list a meal.
  def a_analyzed
    @a_analyzed ||= a_meal.tap do |entry|
      entry.update!(status: "analyzed")
      Nutrition::FoodItem.create!(food_entry: entry, display_name: "Arroz", quantity_grams_min: 100, quantity_grams_likely: 100, quantity_grams_max: 100,
                                  origin: "ai")
    end
  end

  def a_item = a_analyzed.items.first

  # A's goal with a manual check-in, made before the state is taken.
  def a_goal
    @a_goal ||= begin
      id = Goals::Api.create_goal(user_id: a_id, goal_type: "drink_water").id
      Goals::Api.check_in(user_id: a_id, goal_id: id, local_date: Time.use_zone("America/Sao_Paulo") { Time.zone.today })
      Goals::Goal.find(id)
    end
  end

  # Cases that need A's analyzed meal made before the state is taken.
  ANALYZED_CASES = [
    "POST /api/v1/food_entries/:id/confirmation", "POST /api/v1/food_entries/:id/items", "PATCH /api/v1/food_entries/:id/items/:item_id",
    "DELETE /api/v1/food_entries/:id/items/:item_id", "DELETE /api/v1/food_entries/:id", "GET /api/v1/food_entries"
  ].freeze

  ISOLATION_CASES.each do |action, scenario|
    it "#{action}: B acts and nothing of A's changes" do
      if ANALYZED_CASES.include?(action)
        a_analyzed
      elsif action.include?("food_entries/:id")
        a_meal
      end
      a_goal if action.include?("goals")
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
