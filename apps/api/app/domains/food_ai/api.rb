module FoodAi
  # The only entry point to FoodAi for other contexts and controllers. It returns Data
  # objects, never models. Photo upload and analysis operations are added by later tasks.
  module Api
    USER_DATA_TABLES = %w[food_photos food_analysis_results ai_usage_records].freeze

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
