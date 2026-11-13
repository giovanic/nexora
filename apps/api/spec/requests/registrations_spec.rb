require "rails_helper"
require "support/contract"
require "support/identity_helpers"

RSpec.describe "POST /api/v1/registrations", :identity do
  it "mobile gets a token and no cookie" do
    sign_up(client: "mobile")

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("token", "user_id", "expires_at")
    expect(response.headers["Set-Cookie"]).to be_blank
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect_response_to_match_contract
  end

  it "web gets a __Host- cookie and no token in the body" do
    sign_up(client: "web")

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).not_to have_key("token")
    cookie = session_cookie_header
    expect(cookie).to be_present
    expect(cookie.downcase).to include("secure", "httponly", "samesite=lax", "path=/")
    expect(cookie.downcase).not_to include("domain=")
    expect_response_to_match_contract
  end

  it "refuses a web sign up from a foreign Origin" do
    sign_up(client: "web", headers: { "Origin" => "https://evil.example" })

    expect(response).to have_http_status(:forbidden)
    expect(Identity::User.count).to eq(0)
    expect_response_to_match_contract
  end

  it "rejects sign up without adult confirmation" do
    sign_up(adult_confirmed: false)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
    expect(response.parsed_body.dig("error", "details")).to include({ "field" => "adult_confirmed", "code" => "required" })
    expect(Identity::User.count).to eq(0)
    expect_response_to_match_contract
  end

  it "rejects sign up when adult_confirmed is a string instead of true" do
    sign_up(adult_confirmed: "yes")

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "answers email_taken for an existing e-mail, as the design accepts" do
    sign_up
    sign_up(email: " ANA@example.test ")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("email_taken")
    expect(response.parsed_body.dig("error", "message")).not_to include("ana@example.test")
    expect_response_to_match_contract
  end

  it "answers invalid_time_zone for a zone that does not exist, and writes nothing" do
    sign_up(time_zone: "Marte/Base")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_time_zone")
    expect([ Identity::User.count, Shared::Outbox::Event.count ]).to eq([ 0, 0 ])
    expect_response_to_match_contract
  end

  it "publishes user.registered with the time zone" do
    sign_up(time_zone: "America/Manaus")

    expect(Shared::Outbox::Event.sole).to have_attributes(name: "user.registered", payload: { "time_zone" => "America/Manaus" })
  end

  describe "password between 12 characters and 72 bytes" do
    it "refuses 11 characters" do
      sign_up(password: "a" * 11)

      expect(response.parsed_body.dig("error", "details")).to include({ "field" => "password", "code" => "too_short" })
    end

    it "refuses 73 bytes" do
      sign_up(password: "ç" * 36 + "a")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details").map { |detail| detail["field"] }).to eq([ "password" ])
    end

    it "accepts 12 characters" do
      sign_up(password: "a" * 12)

      expect(response).to have_http_status(:created)
    end
  end

  describe "rate limit answers 429 with Retry-After" do
    it "allows 10 sign ups per IP in 3 minutes" do
      10.times { |n| sign_up(email: "person#{n}@example.test") }
      expect(response).to have_http_status(:created)

      sign_up(email: "one-more@example.test")

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("180")
      expect(response.parsed_body.dig("error", "code")).to eq("too_many_requests")
      expect_response_to_match_contract
    end

    it "allows 5 attempts per normalized e-mail in 15 minutes, from any IP" do
      5.times { |n| sign_up(email: n.even? ? "ana@x.com" : " Ana@X.com ", env: { "REMOTE_ADDR" => "198.51.100.#{n}" }) }
      expect(response).not_to have_http_status(:too_many_requests)

      sign_up(email: "ANA@x.com", env: { "REMOTE_ADDR" => "198.51.100.99" })

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to eq("900")
    end

    it "starts counting again after the window" do
      11.times { |n| sign_up(email: "person#{n}@example.test") }

      travel_to(3.minutes.from_now + 1.second) do
        sign_up(email: "later@example.test")

        expect(response).to have_http_status(:created)
      end
    end
  end
end
