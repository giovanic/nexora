module Api
  module V1
    # Asks for the analysis of a meal's uploaded photo. The work happens in a job; the answer only
    # says the meal is processing. FoodAi re-checks the food_photo_ai consent.
    class FoodEntryAnalysesController < ApplicationController
      require_consent :health_data

      STATUS = {
        "entry_not_analyzable" => :conflict,
        "not_uploaded" => :unprocessable_content,
        "invalid_photo" => :unprocessable_content,
        "consent_required" => :forbidden,
        "consent_operator_mismatch" => :forbidden
      }.freeze

      def create
        result = Nutrition::Api.request_analysis(user_id: current_user_id, food_entry_id: params[:id])
        return render_error(:not_found) if result == :not_found
        return render_error(STATUS.fetch(result.code), result.code, details: result.details) unless result.ok?

        render json: { food_entry_id: result.id, status: result.status }, status: :accepted
      end
    end
  end
end
