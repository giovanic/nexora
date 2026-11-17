module Api
  module V1
    # Asks for the analysis of a meal's uploaded photo. The work happens in a job; the answer only
    # says the meal is processing. FoodAi re-checks the food_photo_ai consent.
    class FoodEntryAnalysesController < ApplicationController
      require_consent :health_data

      # 10 requests a minute for one person: each one reads the object from storage. A new request for a
      # failed photo is also capped per photo (analysis_retry_limit).
      rate_limit to: 10, within: 1.minute, name: "food_entry_analysis", only: :create,
                 by: -> { OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("analysis rate limit"), current_user_id.to_s) },
                 with: -> { response.headers["Retry-After"] = "60"; render_error(:too_many_requests) }

      STATUS = {
        "entry_not_analyzable" => :conflict,
        "analysis_retry_limit" => :conflict,
        "analysis_quota_exceeded" => :too_many_requests,
        "not_uploaded" => :unprocessable_content,
        "invalid_photo" => :unprocessable_content,
        "consent_required" => :forbidden,
        "consent_operator_mismatch" => :forbidden
      }.freeze

      def create
        result = Nutrition::Api.request_analysis(user_id: current_user_id, food_entry_id: params[:id])
        return render_error(:not_found) if result == :not_found
        unless result.ok?
          response.headers["Retry-After"] = [ (result.retry_at - Time.current).ceil, 1 ].max.to_s if result.retry_at
          return render_error(STATUS.fetch(result.code), result.code, details: result.details)
        end

        render json: { food_entry_id: result.id, status: result.status }, status: :accepted
      end
    end
  end
end
