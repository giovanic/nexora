module Goals
  class Goal < ApplicationRecord
    self.table_name = "goals"

    STATUSES = %w[active paused ended].freeze
    LIVE = %w[active paused].freeze

    has_many :check_ins, class_name: "Goals::GoalCheckIn", foreign_key: :goal_id, inverse_of: :goal, dependent: :delete_all

    UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    # The person's goal, nil for another person's goal or a malformed id.
    def self.owned(user_id, id, lock: false)
      return unless id.to_s.match?(UUID)

      (lock ? self.lock : all).find_by(user_id:, id:)
    end

    validates :goal_type, inclusion: { in: GoalType::ALL }
    validates :status, inclusion: { in: STATUSES }
    validates :cadence, inclusion: { in: %w[daily] }
    validates :target, numericality: { only_integer: true, equal_to: 1 }
    validates :rule_version, :starts_on, presence: true
    validates :ends_on, presence: true, if: -> { status == "ended" }
  end
end
