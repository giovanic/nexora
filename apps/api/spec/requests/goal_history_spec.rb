require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"

RSpec.describe "/api/v1/goals/history", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:today) { Time.use_zone("America/Sao_Paulo") { Time.zone.today } }

  before do
    run_publisher
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
  end

  def goal_id(type)
    post "/api/v1/goals", params: { goal_type: type }, headers: bearer(token), as: :json
    id = response.parsed_body.fetch("id")
    # A day before the goal started cannot be marked, so the goal starts long ago.
    Goals::Goal.where(id:).update_all(starts_on: Date.new(2026, 1, 1))
    id
  end

  def check_in(id, date) = post("/api/v1/goals/#{id}/check_ins", params: { local_date: date.to_s }, headers: bearer(token), as: :json)
  def history(params = {}, headers: nil) = get("/api/v1/goals/history", params:, headers: headers || bearer(token))

  it "paginates" do
    water = goal_id("drink_water")
    sleep_id = goal_id("sleep_routine")
    [ water, sleep_id ].each { |id| [ today, today - 1 ].each { |date| check_in(id, date) } }

    history({ limit: 3 })

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    first = response.parsed_body
    expect(first.keys).to contain_exactly("items", "next_cursor")
    expect(first["items"].size).to eq(3)
    expect(first["items"].first).to eq("goal_id" => first["items"].first["goal_id"], "goal_type" => first["items"].first["goal_type"],
                                       "goal_status" => "active", "local_date" => today.to_s, "sources" => %w[manual])
    expect(first["next_cursor"]).to be_present

    history({ limit: 3, cursor: first["next_cursor"] })

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    second = response.parsed_body
    expect(second["items"].size).to eq(1)
    expect(second["items"].first).to include("local_date" => (today - 1).to_s)
    expect(second["next_cursor"]).to be_nil
  end

  it "filters by goal" do
    water = goal_id("drink_water")
    other = goal_id("sleep_routine")
    check_in(water, today)
    check_in(other, today)

    history({ goal_id: water })

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    expect(response.parsed_body["items"].pluck("goal_id")).to eq([ water ])
  end

  it "another person's goal_id is 404" do
    other = mobile_token(email: "bia@example.test")
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(other), as: :json
    id = goal_id("drink_water")

    history({ goal_id: id }, headers: bearer(other))

    expect(response).to have_http_status(:not_found)
    expect_response_to_match_contract
  end

  it "limit 101 is 422" do
    history({ limit: 101 })

    expect(response).to have_http_status(:unprocessable_content)
    expect_response_to_match_contract
    expect(response.parsed_body.dig("error", "details")).to include(a_hash_including("field" => "limit"))
  end

  it "a bad cursor is 422" do
    history({ cursor: "nope" })

    expect(response).to have_http_status(:unprocessable_content)
    expect_response_to_match_contract
  end
end
