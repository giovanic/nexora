module Api
  module V1
    # The closed list of daily habit goal types.
    class GoalTypesController < ApplicationController
      require_consent :health_data

      def index
        render json: { goal_types: Goals::Api.goal_types }
      end
    end
  end
end
