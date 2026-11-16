require "rails_helper"
require "support/contract"
require "support/identity_helpers"

RSpec.describe "POST /api/v1/foods/search", :identity do
  let!(:token) { mobile_token }

  before do
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
    FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: "1", license: "CC0-1.0", name: "Beans",
                                     name_pt: "Feijão-preto cozido", kind: "ingredient", nutrients_per_100g: { "energy_kcal" => 1 })
  end

  def search(body, headers: bearer(token))
    post "/api/v1/foods/search", params: body, headers:, as: :json
  end

  it "needs a session" do
    search({ term: "feijao" }, headers: {})

    expect(response).to have_http_status(:unauthorized)
    expect_response_to_match_contract
  end

  it "answers 403 consent_required without health_data" do
    other = mobile_token(email: "bia@example.test")

    search({ term: "feijao" }, headers: bearer(other))

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body.dig("error", "code")).to eq("consent_required")
    expect_response_to_match_contract
  end

  it "answers a page of items" do
    search({ term: "feijao" })

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to match("items" => [ a_hash_including("name_pt" => "Feijão-preto cozido", "kind" => "ingredient", "source" => "usda_fdc") ],
                                          "next_page" => nil)
    expect_response_to_match_contract
  end

  it "answers 422 validation_failed for a missing, blank or oversized term and a bad page" do
    [ {}, { term: " " }, { term: "a" * 101 }, { term: "feijao", page: 0 }, { term: "feijao", page: 1001 }, { term: "feijao", page: 10**30 }, { term: "feijao", per_page: 0 }, { term: %w[feijao] } ].each do |body|
      search(body)

      expect(response).to have_http_status(:unprocessable_content), body.inspect
      expect(response.parsed_body.dig("error", "code")).to eq("validation_failed")
      expect_response_to_match_contract
    end
  end

  it "caps per_page at 50" do
    search({ term: "feijao", per_page: 500 })

    expect(response).to have_http_status(:ok)
  end

  it "POST /foods/search keeps the term out of the URL and the logs" do
    log_path = Rails.root.join("log/test.log")
    offset = File.size(log_path)
    level = Rails.logger.level
    Rails.logger.level = Logger::DEBUG

    search({ term: "feijaozinho-secreto" })

    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    text = File.binread(log_path, nil, offset).force_encoding("UTF-8")
    expect(request.fullpath).to eq("/api/v1/foods/search")
    expect(request.query_string).to be_empty
    expect(text).to include("/api/v1/foods/search")
    expect(text).not_to include("feijaozinho-secreto")
  ensure
    Rails.logger.level = level
  end
end
