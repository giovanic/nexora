module UserProfile
  # One row per account, created by the user.registered consumer. The display
  # name is free text, so it is encrypted and kept out of events and logs.
  class Profile < ApplicationRecord
    self.table_name = "user_profiles"
    self.primary_key = "user_id"

    MOTIVATIONS = %w[start_caring training_consistency understand_food track_progress].freeze
    MAX_MOTIVATIONS = MOTIVATIONS.size
    MAX_DISPLAY_NAME = 60
    UNITS = %w[metric].freeze

    encrypts :display_name

    validates :time_zone, inclusion: { in: ->(_) { TZInfo::Timezone.all_identifiers } }
    validates :units, inclusion: { in: UNITS }
  end
end
