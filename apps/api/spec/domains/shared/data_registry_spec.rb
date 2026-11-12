require "rails_helper"
require "support/outbox_helpers"

RSpec.describe Shared::DataRegistry do
  include OutboxHelpers

  let(:user_id) { SecureRandom.uuid }
  let(:erased) { [] }

  def register_profiles
    described_class.register(
      context: "user_profile",
      tables: %w[user_profiles sport_profiles],
      exporter: ->(id) { { "profile" => { "user_id" => id } } },
      eraser: ->(id) { erased << id }
    )
  end

  it "exports what each context returns for the user, by context" do
    register_profiles

    expect(described_class.export(user_id:)).to include("user_profile" => { "profile" => { "user_id" => user_id } })
  end

  it "lists the erasers by context" do
    register_profiles

    eraser = described_class.erasers.to_h.fetch("user_profile")
    eraser.call(user_id)

    expect(erased).to eq([ user_id ])
  end

  it "lists the registered tables" do
    register_profiles

    expect(described_class.registered_tables).to include("user_profiles", "sport_profiles", "outbox_events")
  end

  it "replaces a context registered again, as a code reload does" do
    register_profiles
    described_class.register(context: "user_profile", tables: %w[user_profiles], exporter: ->(_id) { {} }, eraser: ->(_id) { nil })

    expect(described_class.registered_tables).not_to include("sport_profiles")
    expect(described_class.erasers.count { |context, _| context == "user_profile" }).to eq(1)
  end

  it "refuses a table already registered by another context" do
    register_profiles

    expect do
      described_class.register(context: "goals", tables: %w[user_profiles], exporter: ->(_id) { {} }, eraser: ->(_id) { nil })
    end.to raise_error(ArgumentError, /user_profiles/)
  end

  it "requires an exporter and an eraser that respond to call" do
    expect do
      described_class.register(context: "goals", tables: %w[goals], exporter: nil, eraser: ->(_id) { nil })
    end.to raise_error(ArgumentError)
    expect do
      described_class.register(context: "goals", tables: %w[goals], exporter: ->(_id) { {} }, eraser: "erase")
    end.to raise_error(ArgumentError)
  end

  it "requires at least one table" do
    expect do
      described_class.register(context: "goals", tables: [], exporter: ->(_id) { {} }, eraser: ->(_id) { nil })
    end.to raise_error(ArgumentError)
  end
end
