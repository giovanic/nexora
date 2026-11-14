module Api
  module V1
    # A meal with its items, ranges and confidence, exactly as the clients show it. Another person's
    # meal is a 404. The body carries a signed photo URL, so the response is never cached (no-store, see Authentication).
    class FoodEntriesController < ApplicationController
      require_consent :health_data

      def show
        result = Nutrition::Api.entry(user_id: current_user_id, food_entry_id: params[:id])
        return render_error(:not_found) if result == :not_found

        render json: result.view
      end
    end
  end
end
