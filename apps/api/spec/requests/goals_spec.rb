require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"

RSpec.describe "/api/v1/goals", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }

  before do
    run_publisher
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
  end

  def create_goal(type = "drink_water", headers: bearer(token)) = post("/api/v1/goals", params: { goal_type: type }, headers:, as: :json)

  it "needs a session" do
    get "/api/v1/goals"

    expect(response).to have_http_status(:unauthorized)
    expect_response_to_match_contract
  end

  it "needs health_data" do
    other = mobile_token(email: "bia@example.test")

    [ [ :get, "/api/v1/goal_types" ], [ :get, "/api/v1/goals" ], [ :post, "/api/v1/goals" ], [ :patch, "/api/v1/goals/#{SecureRandom.uuid}" ],
      [ :get, "/api/v1/goals/history" ] ].each do |verb, path|
      # GET carries no body, and `as: :json` would append .json to a route that takes no format.
      options = verb == :get ? {} : { params: { goal_type: "drink_water", status: "paused" }, as: :json }
      public_send(verb, path, headers: bearer(other), **options)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
      expect_response_to_match_contract
    end
  end

  it "lists goal types" do
    get "/api/v1/goal_types", headers: bearer(token)

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    expect(response.parsed_body).to eq("goal_types" => %w[log_meals include_fruits_vegetables drink_water sleep_routine planned_workout])
  end

  it "creates and lists a goal" do
    create_goal

    expect(response).to have_http_status(:created)
    expect_response_to_match_contract
    goal = response.parsed_body
    expect(goal).to include("goal_type" => "drink_water", "status" => "active", "done_today" => false, "done_yesterday" => false)

    get "/api/v1/goals", headers: bearer(token)

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    body = response.parsed_body
    expect(body["goals"]).to eq([ goal ])
    expect(body.keys).to contain_exactly("today_local_date", "yesterday_local_date", "goals")
  end

  it "a repeated create is 200 with the same goal" do
    create_goal
    first = response.parsed_body

    create_goal

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    expect(response.parsed_body).to eq(first)
    expect(Goals::Goal.where(user_id:).count).to eq(1)
  end

  it "forbidden types are 422 unsupported_goal_type with the neutral message and no row" do
    %w[calorie_limit weight_loss].each do |type|
      create_goal(type)

      expect(response).to have_http_status(:unprocessable_content)
      expect_response_to_match_contract
      error = response.parsed_body.fetch("error")
      expect(error).to include("code" => "validation_failed")
      expect(error.fetch("details")).to include(a_hash_including("code" => "unsupported_goal_type"))
      expect(error.to_json).not_to include(type)
    end
    expect(Goals::Goal.where(user_id:)).to be_empty
  end

  it "pauses, resumes, ends" do
    create_goal
    id = response.parsed_body.fetch("id")

    %w[paused active ended].each do |status|
      patch "/api/v1/goals/#{id}", params: { status: }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(response.parsed_body).to include("id" => id, "status" => status)
    end
  end

  it "an invalid status is 422" do
    create_goal

    patch "/api/v1/goals/#{response.parsed_body.fetch('id')}", params: { status: "gone" }, headers: bearer(token), as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect_response_to_match_contract
  end

  it "ended goal is 409 goal_not_active" do
    create_goal
    id = response.parsed_body.fetch("id")
    patch "/api/v1/goals/#{id}", params: { status: "ended" }, headers: bearer(token), as: :json

    patch "/api/v1/goals/#{id}", params: { status: "active" }, headers: bearer(token), as: :json

    expect(response).to have_http_status(:conflict)
    expect_response_to_match_contract
    expect(response.parsed_body.fetch("error")).to include("code" => "goal_not_active", "message" => "Esta meta não está ativa. Retome a meta para marcar o dia.")
  end

  it "deletes a goal" do
    create_goal
    id = response.parsed_body.fetch("id")

    delete "/api/v1/goals/#{id}", headers: bearer(token)

    expect(response).to have_http_status(:no_content)
    expect(Goals::Goal.where(user_id:)).to be_empty
  end

  it "delete works after revoking health_data" do
    create_goal
    id = response.parsed_body.fetch("id")
    delete "/api/v1/consents/health_data", headers: bearer(token)
    run_publisher

    get "/api/v1/goals", headers: bearer(token)
    expect(response).to have_http_status(:forbidden)

    delete "/api/v1/goals/#{id}", headers: bearer(token)

    expect(response).to have_http_status(:no_content)
    expect(Goals::Goal.where(user_id:)).to be_empty
  end

  it "another person's goal is 404 on PATCH and DELETE" do
    other = mobile_token(email: "bia@example.test")
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(other), as: :json
    create_goal
    id = response.parsed_body.fetch("id")

    patch "/api/v1/goals/#{id}", params: { status: "paused" }, headers: bearer(other), as: :json
    expect(response).to have_http_status(:not_found)
    expect_response_to_match_contract

    delete "/api/v1/goals/#{id}", headers: bearer(other)
    expect(response).to have_http_status(:not_found)
    expect_response_to_match_contract
    expect(Goals::Goal.where(user_id:).count).to eq(1)
  end
end
