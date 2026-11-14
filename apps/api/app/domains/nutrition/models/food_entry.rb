module Nutrition
  # A meal. photo_id points to FoodAi's photo by value only; the object key never lives here.
  class FoodEntry < ApplicationRecord
    self.table_name = "food_entries"

    SOURCES = %w[photo manual].freeze
    STATUSES = %w[pending processing analyzed failed confirmed].freeze

    validates :source, inclusion: { in: SOURCES }
    validates :status, inclusion: { in: STATUSES }
    validates :client_request_id, :meal_at, :local_date, presence: true
    validates :client_request_id, uniqueness: { scope: :user_id }
  end
end
