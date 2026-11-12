module Shared
  module Outbox
    class Event < ApplicationRecord
      self.table_name = "outbox_events"

      NAME_FORMAT = /\A[a-z][a-z_]*(\.[a-z][a-z_]*)+\z/

      validates :name, format: { with: NAME_FORMAT }
      validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
      validates :occurred_at, presence: true

      scope :pending, -> { where(published_at: nil, dead_at: nil) }
      scope :due, ->(now = Time.current) { pending.where("next_attempt_at IS NULL OR next_attempt_at <= ?", now) }
    end
  end
end
