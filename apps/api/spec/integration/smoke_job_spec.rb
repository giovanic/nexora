require "rails_helper"
require "support/sidekiq_process"

RSpec.describe "smoke job through a real Sidekiq process", type: :request do
  def poll_until_done(id)
    Timeout.timeout(15, nil, "job was not processed") do
      loop do
        get "/internal/smoke_jobs/#{id}"
        return response.parsed_body if response.parsed_body["status"] == "done"

        sleep 0.1
      end
    end
  end

  it "reports pending before a worker processes the job" do
    post "/internal/smoke_jobs"
    id = response.parsed_body.fetch("id")

    get "/internal/smoke_jobs/#{id}"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("status" => "pending")
  end

  it "processes a job enqueued by the API" do
    SidekiqProcess.with do
      post "/internal/smoke_jobs"

      expect(response).to have_http_status(:accepted)
      expect(poll_until_done(response.parsed_body.fetch("id"))).to eq("status" => "done")
    end
  end
end
