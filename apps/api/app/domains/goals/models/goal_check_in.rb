module Goals
  # source_ref is the food entry's id for food_entry, by value only; manual has none.
  class GoalCheckIn < ApplicationRecord
    self.table_name = "goal_check_ins"

    SOURCES = %w[manual food_entry].freeze

    belongs_to :goal, class_name: "Goals::Goal", inverse_of: :check_ins

    validates :source, inclusion: { in: SOURCES }
    validates :local_date, :checked_at, presence: true
    validates :source_ref, presence: true, if: -> { source == "food_entry" }
    validates :source_ref, absence: true, if: -> { source == "manual" }
  end
end
