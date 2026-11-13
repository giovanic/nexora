module UserProfile
  # A period of a sport at a level. Active while ended_at is nil.
  class SportProfile < ApplicationRecord
    self.table_name = "sport_profiles"

    SPORTS = %w[running walking cycling strength swimming other].freeze
    LEVELS = %w[beginner intermediate advanced].freeze

    scope :active, -> { where(ended_at: nil) }
  end
end
