module Goals
  # The only entry point to Goals for other contexts and controllers. It returns Data objects, never models.
  module Api
    USER_DATA_TABLES = %w[goals goal_check_ins].freeze

    class << self
      def export_user_data(user_id)
        UserData.export(user_id)
      end

      def erase_user_data(user_id)
        UserData.erase(user_id)
      end
    end
  end
end
