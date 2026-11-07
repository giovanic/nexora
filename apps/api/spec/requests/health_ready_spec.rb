require "rails_helper"
require "support/contract"

RSpec.describe "GET /health/ready" do
  def use_check(database: Health::ReadinessCheck.database_probe, queue: Health::ReadinessCheck.queue_probe(Rails.configuration.x.queue_url))
    allow(Health::ReadinessCheck).to receive(:default)
      .and_return(Health::ReadinessCheck.new(database:, queue:))
  end

  it "responds 200 with real PostgreSQL and queue service" do
    get "/health/ready"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "status" => "ok",
      "checks" => { "database" => "ok", "queue" => "ok" }
    )
    expect_response_to_match_contract
  end

  it "responds 503 naming the queue when it is down" do
    use_check(queue: Health::ReadinessCheck.queue_probe("redis://127.0.0.1:1/0"))

    get "/health/ready"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq(
      "status" => "unavailable",
      "checks" => { "database" => "ok", "queue" => "error" }
    )
    expect_response_to_match_contract
  end

  it "responds 503 naming the database when it is down" do
    use_check(database: -> { raise ActiveRecord::ConnectionNotEstablished, "could not connect to secret-host" })

    get "/health/ready"

    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq(
      "status" => "unavailable",
      "checks" => { "database" => "error", "queue" => "ok" }
    )
  end

  it "does not expose connection details when a dependency fails" do
    use_check(database: -> { raise ActiveRecord::ConnectionNotEstablished, "could not connect to secret-host:5432" })

    get "/health/ready"

    expect(response.body).not_to include("secret-host")
    expect(response.body).not_to include("5432")
    expect(response.body).not_to include("ConnectionNotEstablished")
  end
end
