require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"

RSpec.describe "/api/v1/goals/{id}/check_ins", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:today) { Time.use_zone("America/Sao_Paulo") { Time.zone.today } }

  before do
    run_publisher
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
  end

  def goal_id(type = "drink_water")
    post "/api/v1/goals", params: { goal_type: type }, headers: bearer(token), as: :json
    id = response.parsed_body.fetch("id")
    # A day before the goal started cannot be marked, so the goal starts long ago.
    Goals::Goal.where(id:).update_all(starts_on: Date.new(2026, 1, 1))
    id
  end

  def check_in(id, date, headers: bearer(token)) = post("/api/v1/goals/#{id}/check_ins", params: { local_date: date.to_s }, headers:, as: :json)
  def uncheck(id, date, headers: bearer(token)) = delete("/api/v1/goals/#{id}/check_ins/#{date}", headers:)

  it "checks in today and yesterday" do
    id = goal_id

    [ today, today - 1 ].each do |date|
      check_in(id, date)

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(response.parsed_body).to eq("goal_id" => id, "local_date" => date.to_s, "done" => true, "sources" => %w[manual])
    end

    get "/api/v1/goals", headers: bearer(token)
    expect(response.parsed_body["goals"].first).to include("done_today" => true, "done_yesterday" => true)
  end

  it "two days ago is 422 outside_window" do
    id = goal_id

    check_in(id, today - 2)

    expect(response).to have_http_status(:unprocessable_content)
    expect_response_to_match_contract
    expect(response.parsed_body.dig("error", "details")).to include(a_hash_including("field" => "local_date", "code" => "outside_window"))
  end

  it "a malformed date is 422" do
    check_in(goal_id, "nope")

    expect(response).to have_http_status(:unprocessable_content)
    expect_response_to_match_contract
  end

  it "unchecks" do
    id = goal_id
    check_in(id, today)

    uncheck(id, today)

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    expect(response.parsed_body).to include("goal_id" => id, "done" => false, "sources" => [])

    uncheck(id, today - 2)
    expect(response).to have_http_status(:unprocessable_content)
    expect_response_to_match_contract
  end

  it "paused goal is 409" do
    id = goal_id
    patch "/api/v1/goals/#{id}", params: { status: "paused" }, headers: bearer(token), as: :json

    check_in(id, today)

    expect(response).to have_http_status(:conflict)
    expect_response_to_match_contract
    expect(response.parsed_body.dig("error", "code")).to eq("goal_not_active")

    uncheck(id, today)
    expect(response).to have_http_status(:conflict)
    expect_response_to_match_contract
  end

  it "another person's goal is 404" do
    other = mobile_token(email: "bia@example.test")
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(other), as: :json
    id = goal_id

    check_in(id, today, headers: bearer(other))
    expect(response).to have_http_status(:not_found)
    expect_response_to_match_contract

    uncheck(id, today, headers: bearer(other))
    expect(response).to have_http_status(:not_found)
    expect_response_to_match_contract
  end

  it "near midnight in America/Sao_Paulo" do
    id = goal_id

    # 23:30 on 2026-11-16 in Sao Paulo (UTC-3), already 2026-11-17 in UTC.
    travel_to Time.utc(2026, 11, 17, 2, 30) do
      get "/api/v1/goals", headers: bearer(token)
      expect(response.parsed_body).to include("today_local_date" => "2026-11-16", "yesterday_local_date" => "2026-11-15")

      check_in(id, "2026-11-16")
      expect(response).to have_http_status(:ok)
      check_in(id, "2026-11-17")
      expect(response).to have_http_status(:unprocessable_content)
      expect_response_to_match_contract
    end

    # After midnight there, the screen opened before it sends the day before yesterday.
    travel_to Time.utc(2026, 11, 17, 3, 30) do
      check_in(id, "2026-11-15")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include(a_hash_including("code" => "outside_window"))
      expect_response_to_match_contract

      check_in(id, "2026-11-16")
      expect(response).to have_http_status(:ok)
    end
  end
end
