require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"
require "support/food_ai_consent"

RSpec.describe "GET /api/v1/food_entries/{id}", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }
  let(:uuid) { SecureRandom.uuid }

  before do
    run_publisher
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
  end

  def entry(status: "analyzed", user: user_id, photo_id: nil, **attrs)
    Nutrition::FoodEntry.create!(user_id: user, status:, photo_id:, source: "photo", client_request_id: SecureRandom.uuid, meal_at: Time.current,
                                 local_date: Date.current, **attrs)
  end

  def item(entry, name: "Rice", source: "usda_fdc", known: true, confidence: 0.9, kcal: [ 156.04, 195.05, 234.06 ], **attrs)
    Nutrition::FoodItem.create!(
      food_entry: entry, display_name: name, quantity_grams_min: 120, quantity_grams_likely: 150, quantity_grams_max: 180, household_measure: "1 scoop",
      confidence:, catalog_item_id: (SecureRandom.uuid if known), nutrition_source_ref: (known ? { source:, version: "v1", id: "1" } : nil),
      **(known ? { calories_min: kcal[0], calories_likely: kcal[1], calories_max: kcal[2], protein_g_min: 3.24, protein_g_likely: 4.05,
                   protein_g_max: 4.86, carbs_g_min: 33.6, carbs_g_likely: 42, carbs_g_max: 50.4, fat_g_min: 0.36, fat_g_likely: 0.45, fat_g_max: 0.54 } : {}),
      **attrs
    )
  end

  def show(id, headers: bearer(token)) = get("/api/v1/food_entries/#{id}", headers:, as: :json)

  it "needs a session" do
    show(uuid, headers: {})

    expect(response).to have_http_status(:unauthorized)
    expect_response_to_match_contract
  end

  it "needs the health_data consent" do
    other = mobile_token(email: "bia@example.test")

    show(uuid, headers: bearer(other))

    expect(response).to have_http_status(:forbidden)
    expect_response_to_match_contract
  end

  it "another user's entry is 404" do
    other = Identity::Api.register(email: "caio@example.test", password: IdentityHelpers::PASSWORD, adult_confirmed: true, time_zone: "UTC",
                                   client: "mobile", device_label: "x", ip: nil).user_id
    show(entry(user: other).id)

    expect(response).to have_http_status(:not_found)
    expect_response_to_match_contract
  end

  it "an unknown entry is 404" do
    show(uuid)

    expect(response).to have_http_status(:not_found)
  end

  it "serves the meal with ranges rounded only here: calories to ten, macros to the gram" do
    meal = entry
    item(meal)
    item(meal, name: "Beans", source: "project", kcal: [ 100.4, 104.9, 111.0 ])
    meal.update!(estimate_partial: false, calories_min: 256.44, calories_likely: 299.95, calories_max: 345.06)

    show(meal.id)

    expect(response).to have_http_status(:ok)
    expect_response_to_match_contract
    body = response.parsed_body
    expect(body).to include("id" => meal.id, "status" => "analyzed", "result_code" => nil, "estimate_partial" => false, "unknown_items_count" => 0,
                            "confidence" => "medium", "calories_min" => 260, "calories_likely" => 300, "calories_max" => 350,
                            "protein_g_min" => 6, "protein_g_likely" => 8, "protein_g_max" => 10, "photo_url" => nil)
    rice, beans = body["items"]
    expect(rice).to include("name" => "Rice", "source" => "usda_fdc", "own_composition" => false, "unknown" => false, "household_measure" => "1 scoop",
                            "calories_min" => 160, "calories_likely" => 200, "calories_max" => 230, "carbs_g_min" => 34, "fat_g_max" => 1)
    expect(beans).to include("source" => "project", "own_composition" => true)
    expect(body.values_at("calories_min", "calories_likely", "calories_max")).to all(be_an(Integer))
  end

  it "an unknown item shows its name and no numbers, and the estimate is partial" do
    meal = entry
    item(meal)
    item(meal, name: "xyzzy", known: false)

    show(meal.id)

    expect_response_to_match_contract
    body = response.parsed_body
    expect(body).to include("estimate_partial" => true, "unknown_items_count" => 1, "confidence" => "low")
    expect(body["items"].last).to include("name" => "xyzzy", "unknown" => true, "source" => nil, "own_composition" => false, "calories_min" => nil,
                                          "calories_likely" => nil, "calories_max" => nil, "protein_g_min" => nil)
  end

  it "a meal with no known item has no calories and no confidence number" do
    meal = entry
    item(meal, name: "xyzzy", known: false)

    show(meal.id)

    expect_response_to_match_contract
    expect(response.parsed_body).to include("calories_min" => nil, "calories_likely" => nil, "calories_max" => nil, "estimate_partial" => true)
  end

  it "no_food shows the result_code and no items" do
    meal = entry(result_code: "no_food")

    show(meal.id)

    expect_response_to_match_contract
    expect(response.parsed_body).to include("status" => "analyzed", "result_code" => "no_food", "items" => [], "confidence" => nil, "calories_min" => nil)
  end

  it "a processing meal has no numbers yet" do
    show(entry(status: "processing").id)

    expect_response_to_match_contract
    expect(response.parsed_body).to include("status" => "processing", "items" => [], "calories_min" => nil)
  end

  it "response has no total of the day, no remaining and no goal field" do
    meal = entry
    item(meal)

    show(meal.id)

    keys = response.parsed_body.keys + response.parsed_body["items"].flat_map(&:keys)
    expect(keys.grep(/day|daily|total|remaining|left|goal|limit|target|budget|color|score|good|bad/i)).to be_empty
  end

  it "gives a signed photo url while the photo exists, and none after it is deleted" do
    photo = FoodAi::FoodPhoto.create!(user_id:, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}", content_type: "image/jpeg",
                                      status: "stored", authorized_at: Time.current)
    meal = entry(photo_id: photo.id)

    show(meal.id)

    expect_response_to_match_contract
    expect(response.parsed_body["photo_url"]).to eq("memory://download/#{photo.object_key}")

    photo.update!(status: "deleted", deleted_at: Time.current)
    show(meal.id)

    expect(response.parsed_body["photo_url"]).to be_nil
  end

  it "is not cached" do
    show(entry.id)

    expect(response.headers["Cache-Control"]).to include("no-store")
  end
end
