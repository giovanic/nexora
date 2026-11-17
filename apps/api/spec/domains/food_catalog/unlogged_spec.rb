require "rails_helper"

# The SQL log line of a search or match carries the typed food name, in its text and its binds.
# Development broadcasts the log to several loggers, and every one of them must stay silent.
RSpec.describe "food names stay out of every logger" do
  let(:first_io) { StringIO.new }
  let(:second_io) { StringIO.new }
  let(:broadcast) do
    ActiveSupport::BroadcastLogger.new(*[ first_io, second_io ].map { |io| ActiveSupport::Logger.new(io, level: Logger::DEBUG) })
  end

  around do |example|
    original = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = broadcast
    example.run
  ensure
    ActiveRecord::Base.logger = original
  end

  let!(:item) do
    FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: "1", license: "CC0-1.0", name: "Beans",
                                     name_pt: "Feijãozinho secreto", kind: "ingredient", nutrients_per_100g: {})
  end

  before { [ first_io, second_io ].each { |io| io.truncate(0); io.rewind } }

  def written = [ first_io, second_io ].map { |io| io.string.dup }

  it "search returns the right page and writes the term to neither logger" do
    page = FoodCatalog::Api.search(term: "feijaozinho secreto")

    expect(page.items.map(&:id)).to eq([ item.id ])
    expect(written).to all(satisfy { |text| text.exclude?("feijaozinho") })
  end

  it "match returns the right item and writes the name to neither logger" do
    result = FoodCatalog::Api.match(name: "Feijãozinho secreto")

    expect(result.catalog_item_id).to eq(item.id)
    expect(written).to all(satisfy { |text| text.exclude?("feijaozinho") })
  end

  it "runs the lookup exactly once and returns its own result" do
    calls = 0

    result = FoodCatalog::CatalogItem.unlogged { calls += 1; :done }

    expect(calls).to eq(1)
    expect(result).to eq(:done)
  end

  it "still logs other queries on every logger" do
    FoodCatalog::CatalogItem.count

    expect(written).to all(include("food_catalog"))
  end
end
