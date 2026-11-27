module Api
  module V1
    # Marks or unmarks a day of a goal by hand, for today or yesterday.
    class GoalCheckInsController < ApplicationController
      include GoalResponses

      require_consent :health_data

      def create
        render_goal(Goals::Api.check_in(user_id: current_user_id, goal_id: params[:id], local_date: params[:local_date]))
      end

      def destroy
        render_goal(Goals::Api.uncheck(user_id: current_user_id, goal_id: params[:id], local_date: params[:local_date]))
      end
    end
  end
end
