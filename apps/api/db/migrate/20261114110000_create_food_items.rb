# Items of a meal (Nutrition). catalog_item_id is a plain uuid reference to food_catalog, not a foreign
# key: domains never join each other's tables. The numbers are kept unrounded (BigDecimal), rounding
# happens only when a response is built, so the meal's calories columns become decimal too.
class CreateFoodItems < ActiveRecord::Migration[8.1]
  RANGES = %w[calories protein_g carbs_g fat_g].freeze

  def change
    reversible do |dir|
      dir.up { %i[calories_min calories_likely calories_max].each { |column| change_column :food_entries, column, :decimal, precision: 12, scale: 4 } }
      dir.down { %i[calories_min calories_likely calories_max].each { |column| change_column :food_entries, column, :integer, using: "round(#{column})::integer" } }
    end

    create_table :food_items, id: :uuid do |t|
      t.references :food_entry, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :catalog_item_id
      t.string :display_name, null: false
      t.decimal :quantity_grams_min, precision: 8, scale: 2, null: false
      t.decimal :quantity_grams_likely, precision: 8, scale: 2, null: false
      t.decimal :quantity_grams_max, precision: 8, scale: 2, null: false
      t.string :household_measure
      RANGES.each do |name|
        %w[min likely max].each { |bound| t.decimal :"#{name}_#{bound}", precision: 12, scale: 4 }
      end
      t.decimal :confidence, precision: 4, scale: 3
      t.boolean :hidden_ingredients_possible, null: false, default: false
      t.string :origin, null: false, default: "ai"
      t.uuid :corrected_from_item_id
      t.jsonb :nutrition_source_ref
      t.timestamps

      t.check_constraint "quantity_grams_min > 0 AND quantity_grams_min <= quantity_grams_likely AND quantity_grams_likely <= quantity_grams_max",
                         name: "food_items_grams_range"
      RANGES.each do |name|
        t.check_constraint "(#{name}_min IS NULL AND #{name}_likely IS NULL AND #{name}_max IS NULL) OR " \
                           "(#{name}_min IS NOT NULL AND #{name}_likely IS NOT NULL AND #{name}_max IS NOT NULL " \
                           "AND #{name}_min <= #{name}_likely AND #{name}_likely <= #{name}_max)",
                           name: "food_items_#{name}_range"
      end
      t.check_constraint "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)", name: "food_items_confidence_range"
      t.check_constraint "origin IN ('ai', 'user')", name: "food_items_origin_known"
    end
  end
end
