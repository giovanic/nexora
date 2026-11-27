module Api
  module V1
    # The days the person completed a goal, newest first, by cursor.
    class GoalHistoryController < ApplicationController
      include GoalResponses

      require_consent :health_data

      def index
        result = Goals::Api.history(user_id: current_user_id, goal_id: params[:goal_id], cursor: params[:cursor], limit: params[:limit])
        render_goal(result) { |page| { items: page.days.map(&:to_h), next_cursor: page.next_cursor } }
      end
    end
  end
end
