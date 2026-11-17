namespace :food_catalog do
  desc "Load the licensed food catalog (USDA FoodData Central subset and the project's compositions). Idempotent."
  task load: :environment do
    FoodCatalog::LoadCatalog.call
    puts "food catalog: #{FoodCatalog::CatalogItem.where(kind: 'ingredient').count} ingredients, " \
         "#{FoodCatalog::CatalogItem.where(kind: 'composition').count} compositions"
  end
end
