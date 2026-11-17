require "rails_helper"

# bin/rails db:prepare runs db/seeds.rb when it creates a database, as it does on every CI run.
# Catalog specs create their own items and expect an empty catalog, so the seeds must not
# load the reference catalog into the test database.
RSpec.describe "db/seeds.rb" do
  it "loads no reference catalog into the test database" do
    expect { load Rails.root.join("db/seeds.rb") }.not_to change(FoodCatalog::CatalogItem, :count)
  end
end
