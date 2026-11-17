# Reference food data with no personal data: USDA FoodData Central ingredients and the
# project's own dishes. Nothing enters without a license (NOT NULL), and each source
# release is its own row (unique on source, source_version, source_item_id).
#
# Accent-free search: `unaccent()` is not IMMUTABLE, so it cannot sit in an index
# expression. Instead of a wrapper function, name_search holds name_pt already
# lowercased and without accents (set by the model), and the GIN trigram index covers
# it. Only pg_trgm is needed, so the unaccent extension is not enabled.
class CreateFoodCatalog < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"

    create_table :food_catalog, id: :uuid do |t|
      t.string :source, null: false
      t.string :source_version, null: false
      t.string :source_item_id, null: false
      t.string :license, null: false
      t.string :name, null: false
      t.string :name_pt, null: false
      t.string :name_search, null: false
      t.string :kind, null: false
      t.jsonb :nutrients_per_100g, null: false, default: {}
      t.string :review
      t.timestamps

      t.check_constraint "kind::text IN ('ingredient'::text, 'composition'::text)", name: "food_catalog_kind_known"
      t.check_constraint "source::text IN ('usda_fdc'::text, 'project'::text)", name: "food_catalog_source_known"
      t.check_constraint "length(btrim(license)) > 0", name: "food_catalog_license_present"
    end

    add_index :food_catalog, %i[source source_version source_item_id], unique: true, name: "index_food_catalog_on_source_release_item"
    # Serves search (ILIKE and word similarity) and match (similarity) on name_search.
    add_index :food_catalog, :name_search, using: :gin, opclass: :gin_trgm_ops, name: "index_food_catalog_on_name_search_trgm"

    create_table :food_compositions, id: :uuid do |t|
      t.references :catalog_item, type: :uuid, null: false, foreign_key: { to_table: :food_catalog, on_delete: :cascade }, index: false
      t.references :ingredient_catalog_item, type: :uuid, null: false, foreign_key: { to_table: :food_catalog }, index: true
      t.decimal :grams_per_100g, precision: 7, scale: 2, null: false
      t.string :notes

      t.check_constraint "grams_per_100g > 0 AND grams_per_100g <= 100", name: "food_compositions_grams_in_range"
    end

    add_index :food_compositions, %i[catalog_item_id ingredient_catalog_item_id], unique: true, name: "index_food_compositions_on_item_and_ingredient"
  end
end
