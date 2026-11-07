module Internal
  class SmokeJobsController < ActionController::API
    def create
      id = SecureRandom.uuid
      SmokeJob.perform_async(id)

      render json: { id: }, status: :accepted
    end

    def show
      render json: { status: SmokeJob.done?(params[:id]) ? "done" : "pending" }
    end
  end
end
