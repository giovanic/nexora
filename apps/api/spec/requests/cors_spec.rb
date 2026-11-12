require "rails_helper"

RSpec.describe "cross-origin requests" do
  def allow_header_for(origin)
    get "/health/live", headers: { "Origin" => origin }
    response.headers["Access-Control-Allow-Origin"]
  end

  it "allows the local web app in development and test" do
    expect(allow_header_for("http://localhost:5173")).to eq("http://localhost:5173")
  end

  it "does not allow another origin" do
    expect(allow_header_for("http://evil.example")).to be_nil
  end

  describe "AllowedOrigins" do
    it "reads a comma-separated list" do
      expect(AllowedOrigins.from({ "ALLOWED_ORIGINS" => "https://a.test, https://b.test" }))
        .to eq([ "https://a.test", "https://b.test" ])
    end

    it "has no origin in production when the variable is blank" do
      expect(AllowedOrigins.from({ "ALLOWED_ORIGINS" => " " }, environment: "production")).to eq([])
    end

    it "does not inherit the local default in production" do
      expect(AllowedOrigins.from({}, environment: "production")).to eq([])
    end

    it "uses the local web app by default outside production" do
      expect(AllowedOrigins.from({}, environment: "development")).to eq([ "http://localhost:5173" ])
    end

    it "never allows every origin" do
      expect(AllowedOrigins.from({ "ALLOWED_ORIGINS" => "*" })).to eq([])
    end
  end
end
