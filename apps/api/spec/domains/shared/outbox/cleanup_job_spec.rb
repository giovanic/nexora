require "rails_helper"
require "support/outbox_helpers"

RSpec.describe Shared::Outbox::CleanupJob do
  include OutboxHelpers

  def event(**attributes)
    Shared::Outbox::Event.create!(name: "user.registered", occurred_at: 90.days.ago, **attributes)
  end

  def consume(event, consumer = "goals.prepare")
    Shared::Outbox::ConsumedEvent.create!(consumer:, event_id: event.id, consumed_at: Time.current)
  end

  it "cleanup removes events processed more than 30 days ago, with their consumption marks, and keeps the rest" do
    old_published = event(published_at: 31.days.ago)
    old_dead = event(dead_at: 31.days.ago)
    recent_published = event(published_at: 29.days.ago)
    recent_dead = event(dead_at: 29.days.ago)
    pending = event
    [ old_published, recent_published, pending ].each { |item| consume(item) }

    result = described_class.new.perform

    expect(Shared::Outbox::Event.all).to match_array([ recent_published, recent_dead, pending ])
    expect(Shared::Outbox::ConsumedEvent.pluck(:event_id)).to match_array([ recent_published.id, pending.id ])
    expect(result).to eq(events: 2)
  end

  it "keeps a user.deletion_requested event that is still pending" do
    waiting = event(name: "user.deletion_requested")

    described_class.new.perform

    expect(Shared::Outbox::Event.find(waiting.id)).to be_present
  end

  it "is idempotent and works in batches" do
    stub_const("#{described_class}::BATCH", 2)
    5.times { event(published_at: 31.days.ago) }

    expect(described_class.new.perform).to eq(events: 5)
    expect(described_class.new.perform).to eq(events: 0)
  end
end
