require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"

RSpec.describe "profile and sports", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.sole.id }

  def grant_health_data(for_token = token)
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(for_token), as: :json
  end

  def patch_profile(body, headers: bearer(token))
    patch "/api/v1/profile", params: body, headers:, as: :json
  end

  describe "while the profile is pending" do
    before { grant_health_data }

    it "answers 409 profile_pending on every route" do
      get "/api/v1/profile", headers: bearer(token)
      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body.dig("error", "code")).to eq("profile_pending")
      expect_response_to_match_contract

      patch_profile({ display_name: "Ana" })
      expect(response.parsed_body.dig("error", "code")).to eq("profile_pending")
      expect_response_to_match_contract

      get "/api/v1/sport_profiles", headers: bearer(token)
      expect(response.parsed_body.dig("error", "code")).to eq("profile_pending")

      post "/api/v1/sport_profiles", params: { sport: "running", level: "beginner" }, headers: bearer(token), as: :json
      expect(response).to have_http_status(:conflict)
      expect_response_to_match_contract
    end
  end

  describe "with the profile created" do
    before do
      grant_health_data
      run_publisher
    end

    it "shows the profile made at sign up" do
      get "/api/v1/profile", headers: bearer(token)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("display_name" => nil, "time_zone" => "America/Sao_Paulo", "units" => "metric", "motivations" => [])
      expect_response_to_match_contract
    end

    it "updates the profile" do
      patch_profile({ display_name: "Ana", time_zone: "Europe/Lisbon", motivations: %w[start_caring understand_food] })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("display_name" => "Ana", "time_zone" => "Europe/Lisbon", "motivations" => %w[start_caring understand_food])
      expect_response_to_match_contract
    end

    it "replaces the motivations with another set" do
      patch_profile({ motivations: %w[start_caring track_progress] })

      patch_profile({ motivations: %w[understand_food] })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["motivations"]).to eq(%w[understand_food])
      expect_response_to_match_contract
    end

    it "clears the motivations with an empty list" do
      patch_profile({ display_name: "Ana", motivations: %w[start_caring] })

      patch_profile({ motivations: [] })

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("display_name" => "Ana", "motivations" => [])
      expect_response_to_match_contract
    end

    it "invalid time zone is 422 and nothing is saved" do
      patch_profile({ display_name: "Ana", time_zone: "Marte/Base" })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_time_zone")
      expect_response_to_match_contract
      get "/api/v1/profile", headers: bearer(token)
      expect(response.parsed_body).to include("display_name" => nil, "time_zone" => "America/Sao_Paulo")
    end

    it "refuses motivations outside the list and more than 4" do
      patch_profile({ motivations: %w[lose_weight] })
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "motivations", "code" => "inclusion" } ])
      expect_response_to_match_contract

      patch_profile({ motivations: %w[start_caring training_consistency understand_food track_progress start_caring] })
      expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "motivations", "code" => "too_long" } ])
    end

    it "keeps each person's profile apart" do
      patch_profile({ display_name: "Ana" })
      other = mobile_token(email: "bia@example.test")
      grant_health_data(other)
      run_publisher

      get "/api/v1/profile", headers: bearer(other)

      expect(response.parsed_body.fetch("display_name")).to be_nil
    end

    describe "sport profiles" do
      def add(sport, level) = post("/api/v1/sport_profiles", params: { sport:, level: }, headers: bearer(token), as: :json)

      it "adds, lists and changes the level" do
        add("running", "beginner")
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to include("sport" => "running", "level" => "beginner")
        expect_response_to_match_contract
        first_id = response.parsed_body.fetch("id")

        add("running", "advanced")
        expect(response.parsed_body.fetch("id")).not_to eq(first_id)

        get "/api/v1/sport_profiles", headers: bearer(token)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.fetch("sport_profiles").map { |row| row.slice("sport", "level") }).to eq([ { "sport" => "running", "level" => "advanced" } ])
        expect_response_to_match_contract
      end

      it "refuses a sport or level outside the lists" do
        add("chess", "beginner")

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "sport", "code" => "inclusion" } ])
        expect_response_to_match_contract
      end

      it "removes a sport" do
        add("walking", "beginner")
        id = response.parsed_body.fetch("id")

        delete "/api/v1/sport_profiles/#{id}", headers: bearer(token)

        expect(response).to have_http_status(:no_content)
        get "/api/v1/sport_profiles", headers: bearer(token)
        expect(response.parsed_body.fetch("sport_profiles")).to eq([])
      end

      it "answers 404 for another person's sport or an unknown id" do
        add("walking", "beginner")
        id = response.parsed_body.fetch("id")
        other = mobile_token(email: "bia@example.test")
        grant_health_data(other)
        run_publisher

        delete "/api/v1/sport_profiles/#{id}", headers: bearer(other)
        expect(response).to have_http_status(:not_found)
        expect_response_to_match_contract

        delete "/api/v1/sport_profiles/#{SecureRandom.uuid}", headers: bearer(token)
        expect(response).to have_http_status(:not_found)
        get "/api/v1/sport_profiles", headers: bearer(token)
        expect(response.parsed_body.fetch("sport_profiles").size).to eq(1)
      end
    end
  end

  describe "revoking health_data" do
    let(:other_token) { mobile_token(email: "bia@example.test") }
    let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }
    let(:other_id) { Identity::User.find_by!(email: "bia@example.test").id }

    before do
      other_token
      [ token, other_token ].each { |t| grant_health_data(t) }
      run_publisher
      [ token, other_token ].each do |t|
        patch "/api/v1/profile", params: { display_name: "Nome", motivations: %w[start_caring], time_zone: "Europe/Lisbon" }, headers: bearer(t), as: :json
      end
      [ token, other_token ].each { |t| post "/api/v1/sport_profiles", params: { sport: "running", level: "beginner" }, headers: bearer(t), as: :json }
      post "/api/v1/sport_profiles", params: { sport: "running", level: "advanced" }, headers: bearer(token), as: :json
      delete "/api/v1/consents/health_data", headers: bearer(token)
      run_publisher
    end

    it "erases the profile's health data, keeps time zone and units, and leaves other people alone" do
      expect(response).to have_http_status(:no_content)
      expect(UserProfile::SportProfile.where(user_id:)).to be_empty
      expect(UserProfile::Profile.find(user_id)).to have_attributes(display_name: nil, motivations: [], time_zone: "Europe/Lisbon", units: "metric")
      expect(UserProfile::SportProfile.where(user_id: other_id).count).to eq(1)
      expect(UserProfile::Profile.find(other_id)).to have_attributes(display_name: "Nome", motivations: %w[start_caring])
    end

    it "refuses the health routes with 403 consent_required" do
      get "/api/v1/profile", headers: bearer(token)
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("consent_required")

      patch_profile({ display_name: "Ana" })
      expect(response).to have_http_status(:forbidden)
      expect(UserProfile::Profile.find(user_id).display_name).to be_nil
    end

    it "granting again restores access with an empty profile in the same time zone" do
      grant_health_data

      expect(response).to have_http_status(:created)
      get "/api/v1/profile", headers: bearer(token)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("display_name" => nil, "time_zone" => "Europe/Lisbon", "units" => "metric", "motivations" => [])
      get "/api/v1/sport_profiles", headers: bearer(token)
      expect(response.parsed_body.fetch("sport_profiles")).to be_empty
    end
  end

  describe "without health_data" do
    # Controller#action of every authenticated route that works without the
    # health_data consent. Export and account deletion extend it.
    CONSENT_EXEMPT = %w[
      sessions#index sessions#create sessions#refresh sessions#destroy sessions#destroy_current
      consents#index consents#create consents#destroy consents#text
      accounts#export accounts#destroy
    ].freeze
    PUBLIC_CONTROLLERS = %w[api/v1/registrations api/v1/password_resets health].freeze

    def authenticated_routes
      Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        next if route.verb.empty? || controller.nil? || !controller.start_with?("api/") && controller != "health"
        next if PUBLIC_CONTROLLERS.include?(controller)

        [ route.verb, route.path.spec.to_s.delete_suffix("(.:format)").gsub(/:\w+/) { |name| name == ":purpose" ? "health_data" : SecureRandom.uuid },
          "#{controller.delete_prefix('api/v1/')}##{route.defaults[:action]}" ]
      end
    end

    def fresh_token
      Identity::Api.authenticate(email: "ana@example.test", password: IdentityHelpers::PASSWORD, client: "mobile", device_label: nil, ip: nil).session_token
    end

    it "the routes answer 403 consent_required" do
      run_publisher
      %w[/api/v1/profile /api/v1/sport_profiles].each { |path| get path, headers: bearer(token) }
      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
      expect_response_to_match_contract

      patch_profile({ display_name: "Ana" })
      expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
      post "/api/v1/sport_profiles", params: { sport: "running", level: "beginner" }, headers: bearer(token), as: :json
      expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
      delete "/api/v1/sport_profiles/#{SecureRandom.uuid}", headers: bearer(token)
      expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
      expect(UserProfile::Profile.find(user_id).display_name).to be_nil
    end

    it "only sessions, consents and later-allowed routes work without it" do
      routes = authenticated_routes
      expect(routes).not_to be_empty
      reachable = routes.reject do |verb, path, _action|
        send(verb.downcase, path, headers: bearer(fresh_token), as: :json)
        response.status == 403 && response.parsed_body.dig("error", "code") == "consent_required"
      end

      expect(reachable.map(&:last).uniq).to match_array(CONSENT_EXEMPT)
    end
  end
end
