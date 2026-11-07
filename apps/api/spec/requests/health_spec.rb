require "rails_helper"
require "support/contract"

RSpec.describe "GET /health/live" do
  it "confirms the process responds" do
    get "/health/live"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("status" => "wrong")
    expect_response_to_match_contract
  end

  it "does not touch the database" do
    queries = []
    subscriber = ->(*, payload) { queries << payload[:sql] }

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      get "/health/live"
    end

    expect(queries).to be_empty
  end
end
