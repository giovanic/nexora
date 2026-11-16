require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"

# Confirm, correct, add, remove, register by hand, list and delete a meal (AC-03-04, AC-03-05, AC-03-06).
RSpec.describe "managing meals", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }
  let(:uuid) { SecureRandom.uuid }

  before do
    run_publisher
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
  end

  def food(name, kcal:, protein: 1, carbs: 10, fat: 1)
    FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: SecureRandom.hex(4), license: "CC0-1.0", name:, name_pt: name,
                                     kind: "ingredient", nutrients_per_100g: { "energy_kcal" => kcal, "protein_g" => protein, "carbs_g" => carbs, "fat_g" => fat })
  end

  let!(:rice) { food("Arroz", kcal: 130) }
  let!(:beans) { food("Feijão", kcal: 80, protein: 5) }

  def entry(status: "analyzed", user: user_id, local_date: Date.current, meal_at: Time.current, **attrs)
    Nutrition::FoodEntry.create!(user_id: user, status:, source: "photo", client_request_id: SecureRandom.uuid, meal_at:, local_date:, **attrs)
  end

  # An item as the analysis stores it, numbers from the catalog.
  def item(meal, catalog = rice, grams: [ 120, 150, 180 ], origin: "ai", **attrs)
    nutrients = FoodCatalog::Api.nutrients_for(catalog_item_id: catalog.id)
    numbers = Nutrition::Calculator.item(per_100g: nutrients.per_100g, grams_min: grams[0], grams_likely: grams[1], grams_max: grams[2])
    Nutrition::FoodItem.create!(food_entry: meal, display_name: catalog.name_pt, catalog_item_id: catalog.id, quantity_grams_min: grams[0],
                                quantity_grams_likely: grams[1], quantity_grams_max: grams[2], confidence: 0.9, origin:,
                                nutrition_source_ref: { source: "usda_fdc", version: "v1", id: "1" }, **numbers, **attrs)
  end

  def call(verb, path, params = nil, headers: bearer(token)) = public_send(verb, "/api/v1#{path}", params:, headers:, as: (:json unless verb == :get))
  def body = response.parsed_body
  def error_code = body.dig("error", "code")
  def meal_item(name) = body["items"].find { |found| found["name"] == name }

  describe "POST /food_entries/:id/confirmation" do
    it "confirm takes one request and is idempotent" do
      meal = entry
      item(meal)

      call(:post, "/food_entries/#{meal.id}/confirmation")

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(body).to include("status" => "confirmed", "calories_likely" => 200)
      confirmed_at = meal.reload.confirmed_at
      expect(confirmed_at).to be_present

      call(:post, "/food_entries/#{meal.id}/confirmation")

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(body["status"]).to eq("confirmed")
      expect(meal.reload.confirmed_at).to eq(confirmed_at)
    end

    it "confirm on processing is 409" do
      meal = entry(status: "processing")

      call(:post, "/food_entries/#{meal.id}/confirmation")

      expect(response).to have_http_status(:conflict)
      expect(error_code).to eq("entry_not_confirmable")
      expect_response_to_match_contract
      expect(meal.reload.status).to eq("processing")
    end

    it "confirm is 409 for a pending or failed meal and for a meal with no item" do
      %w[pending failed analyzed].each do |status|
        call(:post, "/food_entries/#{entry(status:).id}/confirmation")
        expect(response).to have_http_status(:conflict), status
      end
    end
  end

  describe "PATCH /food_entries/:id/items/:item_id" do
    it "correcting grams recalculates and keeps the original item" do
      meal = entry
      original = item(meal)
      other = item(meal, beans, grams: [ 100, 100, 100 ])
      meal.update!(calories_min: 236, calories_likely: 275, calories_max: 314)

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { grams_likely: 300 })

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(body["items"].size).to eq(2)
      corrected = meal_item("Arroz")
      expect(corrected["id"]).not_to eq(original.id)
      expect(corrected).to include("origin" => "user", "quantity_grams_min" => 240, "quantity_grams_likely" => 300, "quantity_grams_max" => 360,
                                   "calories_min" => 310, "calories_likely" => 390, "calories_max" => 470)
      expect(body).to include("calories_likely" => 470)
      expect(body["items"].map { |found| found["id"] }).to include(other.id)

      expect(Nutrition::FoodItem.where(food_entry_id: meal.id).count).to eq(3)
      expect(original.reload).to have_attributes(hidden_reason: "corrected", quantity_grams_likely: 150)
      expect(original.hidden_at).to be_present
      expect(Nutrition::FoodItem.find(corrected["id"])).to have_attributes(corrected_from_item_id: original.id, origin: "user", confidence: nil)
      expect(meal.reload.calories_likely).to eq(BigDecimal("470"))
    end

    it "correcting to another catalog item keeps the original" do
      meal = entry
      original = item(meal)

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { catalog_item_id: beans.id })

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(body["items"].size).to eq(1)
      expect(body["items"].first).to include("name" => "Feijão", "origin" => "user", "quantity_grams_likely" => 150, "quantity_grams_min" => 120,
                                             "calories_likely" => 120, "unknown" => false)
      expect(Nutrition::FoodItem.find(original.id)).to have_attributes(display_name: "Arroz", hidden_reason: "corrected")
      expect(Nutrition::FoodItem.find(body["items"].first["id"]).corrected_from_item_id).to eq(original.id)
    end

    it "an unknown catalog item is 422" do
      meal = entry
      original = item(meal)

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { catalog_item_id: uuid })

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "details")).to include({ "field" => "catalog_item_id", "code" => "not_found" })
      expect(Nutrition::FoodItem.count).to eq(1)
    end

    it "0 g and 5000 g are 422 without recalculating" do
      meal = entry
      original = item(meal)
      meal.update!(calories_min: 156, calories_likely: 195, calories_max: 234)

      [ 0, 5000, 2000.01, 0.99, -3, "abc", nil ].each do |grams|
        call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { grams_likely: grams })

        expect(response).to have_http_status(:unprocessable_content), grams.inspect
        expect(error_code).to eq("validation_failed")
        expect_response_to_match_contract
      end
      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", {})
      expect(response).to have_http_status(:unprocessable_content)

      expect(Nutrition::FoodItem.count).to eq(1)
      expect(original.reload.hidden_at).to be_nil
      expect(meal.reload.calories_likely).to eq(195)
      expect(response.body).not_to include("5000")
    end

    it "takes 1 g and 2000 g" do
      meal = entry
      original = item(meal)

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { grams_likely: 2000 })
      expect(response).to have_http_status(:ok)
      expect(body["items"].first["quantity_grams_likely"]).to eq(2000)

      call(:patch, "/food_entries/#{meal.id}/items/#{body['items'].first['id']}", { grams_likely: 1 })
      expect(response).to have_http_status(:ok)
      expect(body["items"].first).to include("quantity_grams_likely" => 1, "quantity_grams_min" => 0.8, "quantity_grams_max" => 1.2)
    end

    it "two items with the same name are corrected independently" do
      meal = entry
      first = item(meal)
      second = item(meal, grams: [ 100, 100, 100 ])

      call(:patch, "/food_entries/#{meal.id}/items/#{second.id}", { grams_likely: 200 })

      expect(response).to have_http_status(:ok)
      grams = body["items"].map { |found| found["quantity_grams_likely"] }
      expect(grams).to contain_exactly(150, 200)
      expect(body["items"].map { |found| found["id"] }).to include(first.id)
      expect(first.reload.hidden_at).to be_nil
      expect(second.reload.hidden_reason).to eq("corrected")
    end

    it "an item already corrected, or of another meal, is 404" do
      meal = entry
      original = item(meal)
      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { grams_likely: 200 })

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { grams_likely: 300 })
      expect(response).to have_http_status(:not_found)

      call(:patch, "/food_entries/#{entry.id}/items/#{original.id}", { grams_likely: 300 })
      expect(response).to have_http_status(:not_found)
      expect_response_to_match_contract
    end

    it "a processing meal cannot be edited (409)" do
      meal = entry(status: "processing")
      original = item(meal)

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { grams_likely: 200 })

      expect(response).to have_http_status(:conflict)
      expect(error_code).to eq("entry_not_editable")
      expect_response_to_match_contract
    end

    it "a confirmed meal stays confirmed after a correction" do
      meal = entry(status: "confirmed", confirmed_at: Time.current)
      original = item(meal)

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { grams_likely: 200 })

      expect(body["status"]).to eq("confirmed")
    end
  end

  describe "POST /food_entries/:id/items" do
    it "adds a catalog item as the person's own and recalculates" do
      meal = entry
      item(meal)

      call(:post, "/food_entries/#{meal.id}/items", { catalog_item_id: beans.id, grams_likely: 100 })

      expect(response).to have_http_status(:created)
      expect_response_to_match_contract
      expect(meal_item("Feijão")).to include("origin" => "user", "unknown" => false, "calories_likely" => 80, "quantity_grams_min" => 100, "quantity_grams_max" => 100)
      expect(body).to include("calories_likely" => 280, "estimate_partial" => false)
    end

    it "free text item has no numbers and makes the estimate partial" do
      meal = entry
      item(meal)

      call(:post, "/food_entries/#{meal.id}/items", { free_text_name: "  Pão de queijo ", grams_likely: 50 })

      expect(response).to have_http_status(:created)
      expect_response_to_match_contract
      expect(meal_item("Pão de queijo")).to include("origin" => "user", "unknown" => true, "calories_likely" => nil, "protein_g_likely" => nil, "source" => nil)
      expect(body).to include("estimate_partial" => true, "unknown_items_count" => 1, "calories_likely" => 200, "confidence" => "low")
      expect(meal.reload.estimate_partial).to be(true)
    end

    it "adding to a meal with no food clears its result_code" do
      meal = entry(result_code: "no_food")

      call(:post, "/food_entries/#{meal.id}/items", { catalog_item_id: rice.id, grams_likely: 100 })

      expect(response).to have_http_status(:created)
      expect(body).to include("result_code" => nil, "calories_likely" => 130)
    end

    it "rejects bad input with 422 and adds nothing" do
      meal = entry
      bad = [
        { grams_likely: 100 },
        { free_text_name: "x" * 81, grams_likely: 100 },
        { free_text_name: "   ", grams_likely: 100 },
        { free_text_name: "ok", catalog_item_id: rice.id, grams_likely: 100 },
        { free_text_name: "ok" },
        { free_text_name: "ok", grams_likely: 0 },
        { free_text_name: "ok", grams_likely: 2001 },
        { free_text_name: "ok", grams_likely: 100, grams_min: 150 },
        { free_text_name: "ok", grams_likely: 100, grams_max: 50 },
        { catalog_item_id: uuid, grams_likely: 100 },
        { free_text_name: 5, grams_likely: 100 },
        { free_text_name: "ok", grams_likely: "100" }
      ]
      bad.each do |params|
        call(:post, "/food_entries/#{meal.id}/items", params)
        expect(response).to have_http_status(:unprocessable_content), params.inspect
        expect(error_code).to eq("validation_failed")
        expect_response_to_match_contract
      end
      expect(Nutrition::FoodItem.count).to eq(0)
    end

    it "takes a name of exactly 80 characters" do
      meal = entry

      call(:post, "/food_entries/#{meal.id}/items", { free_text_name: "x" * 80, grams_likely: 100 })

      expect(response).to have_http_status(:created)
    end

    it "a pending meal cannot take items (409)" do
      call(:post, "/food_entries/#{entry(status: 'pending').id}/items", { free_text_name: "x", grams_likely: 10 })

      expect(response).to have_http_status(:conflict)
      expect(error_code).to eq("entry_not_editable")
    end
  end

  describe "DELETE /food_entries/:id/items/:item_id" do
    it "hides the item, keeps the row and recalculates" do
      meal = entry
      item(meal)
      beans_item = item(meal, beans, grams: [ 100, 100, 100 ])

      call(:delete, "/food_entries/#{meal.id}/items/#{beans_item.id}")

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(body["items"].map { |found| found["name"] }).to eq([ "Arroz" ])
      expect(body["calories_likely"]).to eq(200)
      expect(beans_item.reload).to have_attributes(hidden_reason: "removed")
      expect(beans_item.hidden_at).to be_present
      expect(meal.reload.calories_likely).to eq(BigDecimal("195"))

      call(:delete, "/food_entries/#{meal.id}/items/#{beans_item.id}")
      expect(response).to have_http_status(:not_found)
    end

    it "removing the last item leaves a meal with no numbers" do
      meal = entry
      only = item(meal)

      call(:delete, "/food_entries/#{meal.id}/items/#{only.id}")

      expect(body).to include("items" => [], "calories_likely" => nil, "confidence" => nil, "estimate_partial" => false)
      expect(meal.reload.calories_likely).to be_nil
    end
  end

  describe "POST /food_entries (by hand)" do
    def manual(overrides = {})
      call(:post, "/food_entries", { client_request_id: "manual-1", meal_at: Time.current.iso8601, items: [ { catalog_item_id: rice.id, grams_likely: 100 } ] }.merge(overrides))
    end

    it "manual entry is confirmed and does not use the quota" do
      manual(items: [ { catalog_item_id: rice.id, grams_likely: 100 }, { free_text_name: "Molho da casa", grams_likely: 30 } ])

      expect(response).to have_http_status(:created)
      expect_response_to_match_contract
      expect(body).to include("status" => "confirmed", "source" => "manual", "photo_url" => nil, "estimate_partial" => true, "calories_likely" => 130)
      expect(body["items"].map { |found| found["origin"] }).to all(eq("user"))
      meal = Nutrition::FoodEntry.find(body["id"])
      expect(meal).to have_attributes(photo_id: nil, source: "manual", status: "confirmed")
      expect(meal.confirmed_at).to be_present
      expect(FoodAi::FoodPhoto.count).to eq(0)
      expect(FoodAi::UsageRecord.count).to eq(0)
    end

    it "the same client_request_id gives the same meal" do
      manual
      first_id = body["id"]

      manual

      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      expect(body["id"]).to eq(first_id)
      expect(Nutrition::FoodEntry.count).to eq(1)
      expect(Nutrition::FoodItem.count).to eq(1)
    end

    it "a client_request_id of a photo meal is 422" do
      entry.update!(client_request_id: "manual-1")

      manual

      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "details")).to include({ "field" => "client_request_id", "code" => "taken" })
    end

    it "the local date comes from the profile time zone" do
      allow(UserProfile::Api).to receive(:time_zone).with(user_id:).and_return("America/Sao_Paulo")

      manual(meal_at: (Time.current.beginning_of_day + 2.hours).utc.iso8601)

      expect(response).to have_http_status(:created)
      expect(body["local_date"]).to eq((Time.current.beginning_of_day + 2.hours).in_time_zone("America/Sao_Paulo").to_date.iso8601)
    end

    it "422 for no item, too many items, bad items, and nothing is created" do
      [ [], Array.new(31) { { free_text_name: "x", grams_likely: 10 } }, [ { grams_likely: 10 } ], [ { free_text_name: "x", grams_likely: 0 } ], nil ].each do |items|
        manual(items:)
        expect(response).to have_http_status(:unprocessable_content), items.inspect
        expect_response_to_match_contract
      end
      manual(items: [ { free_text_name: "x", grams_likely: 10 }, { free_text_name: "y", grams_likely: 5000 } ])
      expect(body.dig("error", "details")).to include({ "field" => "items.1.grams_likely", "code" => "out_of_range" })
      manual(client_request_id: nil)
      expect(response).to have_http_status(:unprocessable_content)
      expect(Nutrition::FoodEntry.count).to eq(0)
    end
  end

  describe "correcting to another food" do
    it "clears the household measure of the old food, and keeps it when only the grams change" do
      meal = entry
      original = item(meal, household_measure: "1 scoop")

      call(:patch, "/food_entries/#{meal.id}/items/#{original.id}", { catalog_item_id: beans.id })
      expect(body["items"].first["household_measure"]).to be_nil

      other = item(meal, grams: [ 120, 150, 180 ], household_measure: "1 scoop")
      call(:patch, "/food_entries/#{meal.id}/items/#{other.id}", { grams_likely: 150 })
      expect(body["items"].last["household_measure"]).to eq("1 scoop")
    end
  end

  describe "meal_at on both routes" do
    def manual_at(value) = call(:post, "/food_entries", { client_request_id: SecureRandom.uuid, meal_at: value, items: [ { free_text_name: "x", grams_likely: 10 } ] })

    it "needs a UTC offset and a sane window" do
      now = Time.current
      refused = [ "2026-11-14T10:00:00", "2026-11-14", "ontem", 20_261_114, nil, (now + 2.days).iso8601, (now - 31.days).iso8601, "2026-11-14T10:00:00+25:00" ]
      refused.each do |value|
        manual_at(value)
        expect(response).to have_http_status(:unprocessable_content), value.inspect
        expect(body.dig("error", "details")).to include({ "field" => "meal_at", "code" => "invalid" })
        expect_response_to_match_contract
      end
      expect(Nutrition::FoodEntry.count).to eq(0)

      [ (now + 23.hours).iso8601, (now - 29.days).iso8601, now.utc.iso8601, now.in_time_zone("America/Sao_Paulo").iso8601(3) ].each do |value|
        manual_at(value)
        expect(response).to have_http_status(:created), value
      end
    end

    it "the upload route refuses the same values" do
      [ "2026-11-14T10:00:00", (Time.current + 2.days).iso8601, (Time.current - 31.days).iso8601 ].each do |value|
        call(:post, "/food_entries/uploads", { client_request_id: SecureRandom.uuid, content_type: "image/jpeg", byte_size: 1000, meal_at: value })
        expect(response).to have_http_status(:unprocessable_content), value
        expect(error_code).to eq("validation_failed")
      end
      expect(Nutrition::FoodEntry.count).to eq(0)
    end
  end

  describe "GET /food_entries" do
    def make(count, local_date: Date.current, **attrs)
      Array.new(count) do |index|
        meal = entry(local_date:, meal_at: Time.current - index.minutes, **attrs)
        item(meal)
        meal
      end
    end

    it "history is paginated by cursor and capped at 50" do
      make(25)

      call(:get, "/food_entries")
      expect(response).to have_http_status(:ok)
      expect_response_to_match_contract
      first_page = body
      expect(first_page["items"].size).to eq(20)
      expect(first_page["next_cursor"]).to be_present

      call(:get, "/food_entries", { cursor: first_page["next_cursor"] })
      expect_response_to_match_contract
      expect(body["items"].size).to eq(5)
      expect(body["next_cursor"]).to be_nil
      ids = (first_page["items"] + body["items"]).map { |found| found["id"] }
      expect(ids.uniq.size).to eq(25)
      expect(ids).to eq(Nutrition::FoodEntry.order(meal_at: :desc).pluck(:id))
    end

    it "serves at most 50 per page, and 20 by default" do
      make(55)

      call(:get, "/food_entries", { per_page: 500 })
      expect(body["items"].size).to eq(50)
      expect(body["next_cursor"]).to be_present

      call(:get, "/food_entries", { per_page: 5 })
      expect(body["items"].size).to eq(5)

      call(:get, "/food_entries", { per_page: 0 })
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "goes from the newest day to the oldest and filters by local_date" do
      make(2, local_date: Date.current - 2)
      make(2, local_date: Date.current)
      make(1, local_date: Date.current - 1)

      call(:get, "/food_entries")
      expect(body["items"].map { |found| found["local_date"] }).to eq([ Date.current, Date.current, Date.current - 1, Date.current - 2, Date.current - 2 ].map(&:iso8601))

      call(:get, "/food_entries", { local_date: (Date.current - 1).iso8601 })
      expect(body["items"].size).to eq(1)
      expect(body["next_cursor"]).to be_nil

      call(:get, "/food_entries", { local_date: "nope" })
      expect(response).to have_http_status(:unprocessable_content)
      expect_response_to_match_contract
    end

    it "a cursor that is not one is 422" do
      call(:get, "/food_entries", { cursor: "xx" })
      expect(response).to have_http_status(:unprocessable_content)
      expect(body.dig("error", "details")).to include({ "field" => "cursor", "code" => "invalid" })

      call(:get, "/food_entries", { cursor: Base64.urlsafe_encode64("[1,2]") })
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "lists my meals only, without pending ones, each with its items and no total" do
      other = Identity::Api.register(email: "caio@example.test", password: IdentityHelpers::PASSWORD, adult_confirmed: true, time_zone: "UTC",
                                     client: "mobile", device_label: "x", ip: nil).user_id
      entry(user: other)
      entry(status: "pending")
      mine = make(1).first

      call(:get, "/food_entries")

      expect(body["items"].map { |found| found["id"] }).to eq([ mine.id ])
      expect(body["items"].first["items"].size).to eq(1)
      expect(body.keys).to eq(%w[items next_cursor])
      keys = body["items"].flat_map(&:keys)
      expect(keys.grep(/day|daily|total|sum|remaining|left|goal|limit|target|budget/i)).to be_empty
    end

    it "hidden items are not shown" do
      meal = make(1).first
      item(meal, beans).update!(hidden_at: Time.current, hidden_reason: "removed")

      call(:get, "/food_entries")

      expect(body["items"].first["items"].map { |found| found["name"] }).to eq([ "Arroz" ])
    end

    it "gives no photo url in the history, even while the photo exists" do
      photo = FoodAi::FoodPhoto.create!(user_id:, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}", content_type: "image/jpeg",
                                        status: "stored", authorized_at: Time.current)
      entry(photo_id: photo.id)

      call(:get, "/food_entries")

      expect(body["items"].first["photo_url"]).to be_nil
    end

    it "history query count is the same for 5 and 15 entries" do
      make_with_photos = lambda do |count|
        make(count).each do |meal|
          photo = FoodAi::FoodPhoto.create!(user_id:, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}",
                                            content_type: "image/jpeg", status: "stored", authorized_at: Time.current)
          meal.update!(photo_id: photo.id)
          item(meal, beans)
        end
      end
      count_queries = lambda do
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          queries << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:cached]
        end
        call(:get, "/food_entries", { per_page: 50 })
        ActiveSupport::Notifications.unsubscribe(subscriber)
        queries
      end
      call(:get, "/food_entries") # warm up (session, consent)

      make_with_photos.call(5)
      few = count_queries.call
      expect(body["items"].size).to eq(5)

      make_with_photos.call(10)
      many = count_queries.call
      expect(body["items"].size).to eq(15)

      expect(many.size).to eq(few.size), "#{few.size} queries for 5 entries, #{many.size} for 15:\n#{many.join("\n")}"
    end
  end

  describe "DELETE /food_entries/:id" do
    def photo_for(meal)
      photo = FoodAi::FoodPhoto.create!(user_id:, food_entry_id: meal.id, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}",
                                        content_type: "image/jpeg", byte_size: 3, status: "stored", authorized_at: Time.current)
      FoodAi.storage.write(key: photo.object_key, bytes: "abc", content_type: "image/jpeg")
      meal.update!(photo_id: photo.id)
      photo
    end

    it "delete removes items, photo and raw_response" do
      meal = entry
      item(meal)
      item(meal, beans).update!(hidden_at: Time.current, hidden_reason: "removed")
      photo = photo_for(meal)
      analysis = FoodAi::AnalysisResult.create!(user_id:, photo_id: photo.id, provider: "fake", model: "fake-1", prompt_version: "food_vision_v1", schema_version: "1",
                                                status: "succeeded", raw_response: { "contains_food" => true }, started_at: Time.current)
      usage = FoodAi::UsageRecord.create!(analysis_id: analysis.id, user_id:, provider: "fake", model: "fake-1", input_tokens: 1, output_tokens: 1,
                                          cost_usd: BigDecimal("0.000001"), occurred_at: Time.current)

      call(:delete, "/food_entries/#{meal.id}")

      expect(response).to have_http_status(:no_content)
      expect_response_to_match_contract
      expect(Nutrition::FoodEntry.where(id: meal.id)).to be_empty
      expect(Nutrition::FoodItem.where(food_entry_id: meal.id)).to be_empty
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi::AnalysisResult.where(id: analysis.id)).to be_empty
      expect(usage.reload.analysis_id).to be_nil
    end

    it "works with the health_data consent revoked, and still erases items, photo and analyses" do
      meal = entry
      item(meal)
      photo = photo_for(meal)
      analysis = FoodAi::AnalysisResult.create!(user_id:, photo_id: photo.id, provider: "fake", model: "fake-1", prompt_version: "food_vision_v1", schema_version: "1",
                                                status: "succeeded", raw_response: { "contains_food" => true }, started_at: Time.current)
      call(:delete, "/consents/health_data")
      expect(response).to have_http_status(:no_content)

      call(:delete, "/food_entries/#{meal.id}")

      expect(response).to have_http_status(:no_content)
      expect_response_to_match_contract
      expect(Nutrition::FoodEntry.where(id: meal.id)).to be_empty
      expect(Nutrition::FoodItem.where(food_entry_id: meal.id)).to be_empty
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi::AnalysisResult.where(id: analysis.id)).to be_empty
    end

    it "with the consent revoked, another user's meal is still 404 and stays" do
      other = Identity::Api.register(email: "caio@example.test", password: IdentityHelpers::PASSWORD, adult_confirmed: true, time_zone: "UTC",
                                     client: "mobile", device_label: "x", ip: nil).user_id
      theirs = entry(user: other)
      call(:delete, "/consents/health_data")

      call(:delete, "/food_entries/#{theirs.id}")

      expect(response).to have_http_status(:not_found)
      expect(Nutrition::FoodEntry.where(id: theirs.id)).to exist
    end

    it "calls FoodAi after the commit, outside the transaction" do
      meal = entry
      inside = nil
      allow(FoodAi::Api).to receive(:erase_for_entry) do |**|
        inside = [ Nutrition::FoodEntry.where(id: meal.id).exists?, Nutrition::FoodEntry.connection.open_transactions ]
      end

      call(:delete, "/food_entries/#{meal.id}")

      expect(FoodAi::Api).to have_received(:erase_for_entry).with(user_id:, food_entry_id: meal.id, photo_id: nil)
      # The spec itself runs inside a test transaction (1): the delete adds none while FoodAi runs.
      expect(inside).to eq([ false, 1 ])
    end

    it "a storage failure still answers 204, deletes the photo row and queues the object for purge, with no key in the logs" do
      meal = entry
      photo = photo_for(meal)
      allow(FoodAi.storage).to receive(:delete).and_raise(IOError, "boom #{photo.object_key}")
      allow(FoodAi::PurgeObjectJob).to receive(:perform_async)
      logged = StringIO.new
      allow(Rails).to receive(:logger).and_return(Logger.new(logged))

      call(:delete, "/food_entries/#{meal.id}")

      expect(response).to have_http_status(:no_content)
      expect(Nutrition::FoodEntry.where(id: meal.id)).to be_empty
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi::PurgeObjectJob).to have_received(:perform_async).with(photo.id)
      expect(logged.string).not_to include(photo.object_key)
    end

    it "the purge job deletes the object later" do
      meal = entry
      photo = photo_for(meal)
      calls = 0
      allow(FoodAi.storage).to receive(:delete).and_wrap_original { |original, **args| (calls += 1) == 1 ? raise(IOError) : original.call(**args) }
      allow(FoodAi::PurgeObjectJob).to receive(:perform_async)

      call(:delete, "/food_entries/#{meal.id}")
      FoodAi::PurgeObjectJob.new.perform(photo.id)

      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
    end

    it "a photo linked to the meal only by photo_id is erased too" do
      meal = entry
      photo = photo_for(meal)
      photo.update!(food_entry_id: nil)

      call(:delete, "/food_entries/#{meal.id}")

      expect(response).to have_http_status(:no_content)
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
    end

    it "works while the analysis runs" do
      meal = entry(status: "processing")

      call(:delete, "/food_entries/#{meal.id}")

      expect(response).to have_http_status(:no_content)
      expect(Nutrition::FoodEntry.count).to eq(0)
    end

    it "a second delete is 404" do
      meal = entry
      call(:delete, "/food_entries/#{meal.id}")
      call(:delete, "/food_entries/#{meal.id}")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "isolation and access" do
    let(:other_id) do
      Identity::Api.register(email: "caio@example.test", password: IdentityHelpers::PASSWORD, adult_confirmed: true, time_zone: "UTC",
                             client: "mobile", device_label: "x", ip: nil).user_id
    end

    it "every route answers 404 for another user's entry" do
      meal = entry(user: other_id)
      theirs = item(meal)
      mine = entry
      my_item = item(mine)
      foreign = [
        [ :post, "/food_entries/#{meal.id}/confirmation", nil ],
        [ :patch, "/food_entries/#{meal.id}/items/#{theirs.id}", { grams_likely: 10 } ],
        [ :post, "/food_entries/#{meal.id}/items", { free_text_name: "x", grams_likely: 10 } ],
        [ :delete, "/food_entries/#{meal.id}/items/#{theirs.id}", nil ],
        [ :delete, "/food_entries/#{meal.id}", nil ],
        # My meal with their item id, and their meal with my item id.
        [ :patch, "/food_entries/#{mine.id}/items/#{theirs.id}", { grams_likely: 10 } ],
        [ :delete, "/food_entries/#{mine.id}/items/#{theirs.id}", nil ],
        [ :patch, "/food_entries/#{meal.id}/items/#{my_item.id}", { grams_likely: 10 } ]
      ]
      before = [ Nutrition::FoodEntry.count, Nutrition::FoodItem.pluck(:id, :hidden_at, :quantity_grams_likely) ]

      foreign.each do |verb, path, params|
        call(verb, path, params)
        expect(response).to have_http_status(:not_found), "#{verb} #{path}"
        expect_response_to_match_contract
        expect(response.body).not_to include(meal.id, theirs.id, other_id)
      end
      expect([ Nutrition::FoodEntry.count, Nutrition::FoodItem.pluck(:id, :hidden_at, :quantity_grams_likely) ]).to eq(before)
    end

    it "an unknown or malformed id is 404" do
      call(:post, "/food_entries/#{uuid}/confirmation")
      expect(response).to have_http_status(:not_found)
      call(:delete, "/food_entries/#{uuid}")
      expect(response).to have_http_status(:not_found)
      call(:delete, "/food_entries/#{entry.id}/items/#{uuid}")
      expect(response).to have_http_status(:not_found)
      call(:delete, "/food_entries/#{entry.id}/items/not-a-uuid")
      expect(response).to have_http_status(:not_found)
    end

    let(:routes) do
      [
      [ :get, "/food_entries" ], [ :post, "/food_entries" ], [ :post, "/food_entries/ID/confirmation" ],
      [ :post, "/food_entries/ID/items" ], [ :patch, "/food_entries/ID/items/ITEM" ], [ :delete, "/food_entries/ID/items/ITEM" ]
      ]
    end

    it "every route but the delete of a whole meal needs a session and the health_data consent" do
      without_consent = mobile_token(email: "bia@example.test")
      routes.each do |verb, path|
        path = path.sub("ID", uuid).sub("ITEM", uuid)

        call(verb, path, nil, headers: {})
        expect(response).to have_http_status(:unauthorized), "#{verb} #{path}"
        expect_response_to_match_contract

        call(verb, path, nil, headers: bearer(without_consent))
        expect(response).to have_http_status(:forbidden), "#{verb} #{path}"
        expect_response_to_match_contract
      end
    end

    it "deleting a whole meal needs a session, but not the health_data consent (right to erasure)" do
      without_consent = mobile_token(email: "bia@example.test")

      call(:delete, "/food_entries/#{uuid}", nil, headers: {})
      expect(response).to have_http_status(:unauthorized)
      expect_response_to_match_contract

      call(:delete, "/food_entries/#{uuid}", nil, headers: bearer(without_consent))
      expect(response).to have_http_status(:not_found)
      expect_response_to_match_contract
    end

    it "after a revocation of health_data the other meal routes keep answering 403 consent_required" do
      meal = entry
      kept = item(meal)
      call(:delete, "/consents/health_data")
      expect(response).to have_http_status(:no_content)

      [ [ :get, "/food_entries/#{meal.id}" ], [ :get, "/food_entries" ], [ :post, "/food_entries/#{meal.id}/confirmation" ],
        [ :post, "/food_entries/#{meal.id}/items" ], [ :patch, "/food_entries/#{meal.id}/items/#{kept.id}" ],
        [ :delete, "/food_entries/#{meal.id}/items/#{kept.id}" ] ].each do |verb, path|
        call(verb, path)
        expect(response).to have_http_status(:forbidden), "#{verb} #{path}"
        expect(error_code).to eq("consent_required")
      end
      expect(Nutrition::FoodEntry.where(id: meal.id)).to exist
    end

    it "the free text name and the catalog terms are filtered from logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      expect(filter.filter({ "free_text_name" => "pão", "grams_likely" => 10, "items" => [ { "free_text_name" => "x" } ] }))
        .to eq({ "free_text_name" => "[FILTERED]", "grams_likely" => "[FILTERED]", "items" => "[FILTERED]" })
    end
  end
end
