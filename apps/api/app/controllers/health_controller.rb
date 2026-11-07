class HealthController < ActionController::API
  def live
    render json: { status: "ok" }
  end
end
