module Internal
  class SmokeErrorsController < ActionController::API
    def create
      raise SmokeError, "provoked request error" unless params[:target] == "job"

      SmokeErrorJob.perform_async
      head :accepted
    end
  end
end
