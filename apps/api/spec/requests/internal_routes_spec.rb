require "rails_helper"

RSpec.describe "internal routes" do
  it "rejects an identifier that is not a UUID" do
    get "/internal/smoke_jobs/*"

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.dig("error", "code")).to eq("not_found")
  end

  context "in production" do
    before do
      allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
      Rails.application.reload_routes!
    end

    after do
      allow(Rails).to receive(:env).and_call_original
      Rails.application.reload_routes!
    end

    it "does not expose the smoke job route" do
      post "/internal/smoke_jobs"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    end
  end
end
