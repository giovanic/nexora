require "rails_helper"
require "support/outbox_helpers"

RSpec.describe FoodAi::SpendAlertJob do
  include OutboxHelpers
  include SentryCapture

  let(:user) { Identity::User.create!(email: "spend-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current) }

  before { Rails.cache.clear }
  after { Rails.cache.clear }

  def spend(amount, at: Time.current)
    FoodAi::UsageRecord.create!(user_id: user.id, provider: "fake", model: "fake-1", cost_usd: BigDecimal(amount), occurred_at: at)
  end

  it "spend alert fires once above the limit and not below it" do
    travel_to(Time.utc(2026, 11, 14, 6)) do
      spend("9.99")
      described_class.new.perform
      expect(sentry_events).to be_empty

      spend("0.02")
      2.times { described_class.new.perform }

      expect(sentry_events.size).to eq(1)
      event = sentry_events.first
      expect(event.tags).to include(food_ai_spend_usd: "10.01", food_ai_limit_usd: "10.0")
      serialized = event.to_json_compatible.to_json
      expect(serialized).not_to include(user.id, user.email)
    end
  end

  it "does not count the cost of another month" do
    travel_to(Time.utc(2026, 11, 14, 6)) do
      spend("50", at: Time.utc(2026, 10, 31, 23))

      described_class.new.perform

      expect(sentry_events).to be_empty
    end
  end

  it "alerts again in the next month" do
    travel_to(Time.utc(2026, 11, 14, 6)) do
      spend("11")
      described_class.new.perform
    end
    travel_to(Time.utc(2026, 12, 2, 6)) do
      spend("11")
      described_class.new.perform
    end

    expect(sentry_events.size).to eq(2)
  end

  it "alerts again when the limit changes" do
    travel_to(Time.utc(2026, 11, 14, 6)) do
      spend("30")
      described_class.new.perform
      configure_food_ai_env("FOOD_AI_MONTHLY_ALERT_USD" => "20")
      described_class.new.perform
      described_class.new.perform
    end

    expect(sentry_events.size).to eq(2)
    expect(sentry_events.last.tags).to include(food_ai_limit_usd: "20.0")
  end

  it "uses 10 when the setting is invalid" do
    configure_food_ai_env("FOOD_AI_MONTHLY_ALERT_USD" => "abc")
    spend("10.5")

    described_class.new.perform

    expect(sentry_events.sole.tags).to include(food_ai_limit_usd: "10.0")
  end
end
