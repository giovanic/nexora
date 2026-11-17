module FoodAi
  # Cost of one provider call. analysis_id is cleared when the meal and its analysis are
  # deleted, so the cost survives unlinked; user_id is cleared by the 90-day retention.
  class UsageRecord < ApplicationRecord
    self.table_name = "ai_usage_records"

    # Plain identifiers, not free text. Which models exist is FoodAi::Pricing's job (it raises on an unknown one).
    IDENTIFIER = /\A[a-z0-9][a-z0-9._-]*\z/

    validates :provider, :model, format: { with: IDENTIFIER }, length: { maximum: 64 }
    validates :occurred_at, presence: true
    validates :input_tokens, :output_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :cost_usd, numericality: { greater_than_or_equal_to: 0 }
  end
end
