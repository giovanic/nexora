module Api
  module V1
    # The person's daily habit goals: list, create, pause/resume/end and delete. Another person's goal is a 404.
    class GoalsController < ApplicationController
      include GoalResponses

      # Deleting a goal is erasure (LGPD art. 18): it must work after health_data is revoked.
      require_consent :health_data, except: :destroy

      def index
        list = Goals::Api.list_goals(user_id: current_user_id)
        render json: { today_local_date: list.today_local_date, yesterday_local_date: list.yesterday_local_date,
                       goals: list.goals.map { |goal| goal.to_h.except(:created) } }
      end

      def create
        result = Goals::Api.create_goal(user_id: current_user_id, goal_type: params[:goal_type])
        render_goal(result, status: result.ok? && !result.created ? :ok : :created)
      end

      def update
        render_goal(Goals::Api.change_status(user_id: current_user_id, goal_id: params[:id], status: params[:status]))
      end

      def destroy
        return render_error(:not_found) if Goals::Api.delete_goal(user_id: current_user_id, goal_id: params[:id]) == :not_found

        head :no_content
      end
    end
  end
end
