require "rails_helper"
require "support/identity_helpers"
require "support/food_ai_consent"

RSpec.describe "Nutrition::Api.start_photo_entry" do
  include ActiveSupport::Testing::TimeHelpers

  self.use_transactional_tests = false

  let(:user) { Identity::User.create!(email: "nu-#{SecureRandom.hex(4)}@example.test", password: IdentityHelpers::PASSWORD, adult_confirmed_at: Time.current) }

  before do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
  end

  after { ActiveRecord::Base.connection.execute("TRUNCATE users, food_photos, food_entries, consent_records, outbox_events, audit_events CASCADE") }

  def start(client_request_id: "req-1")
    Nutrition::Api.start_photo_entry(user_id: user.id, client_request_id:, content_type: "image/jpeg", byte_size: 1000, meal_at: Time.current.iso8601)
  end

  it "two concurrent requests with the same client_request_id create one entry" do
    gate = Queue.new
    threads = 3.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          start(client_request_id: "race")
        end
      end
    end
    3.times { gate << true }
    results = threads.map(&:value)

    expect(results).to all(be_ok)
    expect(results.map(&:food_entry_id).uniq.size).to eq(1)
    expect(Nutrition::FoodEntry.count).to eq(1)
    expect(FoodAi::FoodPhoto.count).to eq(1)
    expect(FoodAi::FoodPhoto.sole.food_entry_id).to eq(Nutrition::FoodEntry.sole.id)
  end

  it "does not create an entry when FoodAi refuses" do
    Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")

    expect(start).to have_attributes(code: "consent_required")
    expect(Nutrition::FoodEntry.count).to eq(0)
  end

  it "recovers an authorized photo that never got its entry, on the retry" do
    FoodAi::Api.authorize_photo_upload(user_id: user.id, client_request_id: "half", content_type: "image/jpeg", byte_size: 1000,
                                       day_start: Time.current.beginning_of_day, day_end: Time.current.end_of_day)

    result = start(client_request_id: "half")

    expect(result).to be_ok
    expect(FoodAi::FoodPhoto.sole.food_entry_id).to eq(result.food_entry_id)
  end

  it "exports and erases only Nutrition's rows" do
    start
    export = Nutrition::Api.export_user_data(user.id)

    expect(export[:entries].size).to eq(1)
    expect(export[:entries].first).to include(status: "pending", source: "photo")
    expect(export[:entries].first.keys).not_to include(:photo_id, :user_id)

    Nutrition::Api.erase_user_data(user.id)

    expect(Nutrition::FoodEntry.count).to eq(0)
    expect(FoodAi::FoodPhoto.count).to eq(1)
  end

  it "local_date of a meal at 23:30 in São Paulo is that local day" do
    travel_to(Time.utc(2026, 11, 12, 12))
    allow(UserProfile::Api).to receive(:time_zone).with(user_id: user.id).and_return("America/Sao_Paulo")

    result = Nutrition::Api.start_photo_entry(user_id: user.id, client_request_id: "late", content_type: "image/jpeg", byte_size: 1000,
                                              meal_at: "2026-11-10T23:30:00-03:00")

    expect(result).to be_ok
    entry = Nutrition::FoodEntry.find(result.food_entry_id)
    expect(entry.meal_at.utc.to_date).to eq(Date.new(2026, 11, 11))
    expect(entry.local_date).to eq(Date.new(2026, 11, 10))
  end

  it "enforces the food_items ranges, confidence and origin in the database, and cascades on delete" do
    start
    entry = Nutrition::FoodEntry.sole
    base = { food_entry_id: entry.id, display_name: "x", quantity_grams_min: 1, quantity_grams_likely: 2, quantity_grams_max: 3 }

    [ { quantity_grams_min: 5 }, { calories_min: 5, calories_likely: 4, calories_max: 6 }, { calories_min: 1 }, { confidence: 1.5 }, { origin: "model" } ].each do |bad|
      expect { Nutrition::FoodItem.new(base.merge(bad)).save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    Nutrition::FoodItem.create!(base)
    entry.delete
    expect(Nutrition::FoodItem.count).to eq(0)
  end

  it "enforces the status list and the calories range in the database" do
    start
    entry = Nutrition::FoodEntry.sole
    expect { entry.update_columns(status: "weird") }.to raise_error(ActiveRecord::StatementInvalid)
    expect { entry.update_columns(calories_min: 500, calories_likely: 400, calories_max: 600) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "meal_at needs a UTC offset, at most 1 day ahead and 30 days back" do
    now = Time.current
    [ "2026-11-14T10:00:00", "2026-11-14", (now + 2.days).iso8601, (now - 31.days).iso8601, nil, 5 ].each do |value|
      result = Nutrition::Api.start_photo_entry(user_id: user.id, client_request_id: "w", content_type: "image/jpeg", byte_size: 1000, meal_at: value)

      expect(result).to have_attributes(code: "validation_failed", details: [ { field: "meal_at", code: "invalid" } ])
    end
    expect(Nutrition::FoodEntry.count + FoodAi::FoodPhoto.count).to eq(0)
  end

  describe "when creating the entry raises RecordInvalid" do
    it "treats only the client_request_id uniqueness as a lost race" do
      FoodAi::Api.authorize_photo_upload(user_id: user.id, client_request_id: "race", content_type: "image/jpeg", byte_size: 1000,
                                         day_start: Time.current.beginning_of_day, day_end: Time.current.end_of_day)
      taken = Nutrition::FoodEntry.new
      taken.errors.add(:client_request_id, :taken)
      winner = Nutrition::FoodEntry.create!(user_id: user.id, client_request_id: "race", meal_at: Time.current, local_date: Date.current)
      calls = 0
      allow(Nutrition::FoodEntry).to receive(:find_by).and_wrap_original do |original, *args|
        calls += 1
        calls == 1 ? nil : original.call(*args)
      end
      allow(Nutrition::FoodEntry).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(taken))

      expect(start(client_request_id: "race").food_entry_id).to eq(winner.id)
    end

    it "does not hide any other validation failure" do
      other = Nutrition::FoodEntry.new
      other.errors.add(:meal_at, :blank)
      allow(Nutrition::FoodEntry).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(other))

      expect { start(client_request_id: "other") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
