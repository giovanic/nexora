require "rails_helper"

RSpec.describe Goals::RemovedFoodEntriesRetentionJob do
  let(:user_id) { Identity::User.create!(email: "r-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id }

  def marker(age) = Goals::RemovedFoodEntry.create!(user_id:, food_entry_id: SecureRandom.uuid, created_at: age.ago)

  it "uses the same period as the published outbox events" do
    expect(described_class::PERIOD).to eq(Shared::Outbox::CleanupJob::PERIOD)
  end

  it "deletes markers older than 30 days and keeps the newer ones" do
    old = marker(31.days)
    recent = marker(29.days)

    result = described_class.new.perform

    expect(result).to eq({ removed_food_entries: 1 })
    expect(Goals::RemovedFoodEntry.pluck(:id)).to eq([ recent.id ])
    expect(Goals::RemovedFoodEntry.exists?(old.id)).to be(false)
  end

  it "deletes in batches and finds nothing on a second run" do
    stub_const("#{described_class}::BATCH", 2)
    5.times { marker(40.days) }

    expect(described_class.new.perform).to eq({ removed_food_entries: 5 })
    expect(described_class.new.perform).to eq({ removed_food_entries: 0 })
  end

  it "is scheduled daily" do
    entry = YAML.load_file(Rails.root.join("config/schedule.yml")).values.find { |job| job["class"] == described_class.name }

    expect(entry).to include("cron" => "0 4 * * *", "queue" => "default")
  end
end
