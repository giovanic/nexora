module Nutrition
  # A meal. photo_id points to FoodAi's photo by value only; the object key never lives here.
  class FoodEntry < ApplicationRecord
    self.table_name = "food_entries"

    SOURCES = %w[photo manual].freeze
    STATUSES = %w[pending processing analyzed failed confirmed].freeze

    has_many :items, class_name: "Nutrition::FoodItem", foreign_key: :food_entry_id, inverse_of: :food_entry, dependent: :delete_all
    # The items the person sees: not corrected away and not removed.
    has_many :visible_items, -> { where(hidden_at: nil) }, class_name: "Nutrition::FoodItem", foreign_key: :food_entry_id, inverse_of: false

    validates :source, inclusion: { in: SOURCES }
    validates :status, inclusion: { in: STATUSES }
    validates :client_request_id, :meal_at, :local_date, presence: true
    validates :client_request_id, uniqueness: { scope: :user_id }
  end
end
