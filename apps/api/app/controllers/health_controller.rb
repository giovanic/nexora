class HealthController < ActionController::API
  def live
    render json: { status: "ok" }
  end

  def ready
    result = Health::ReadinessCheck.default.call

    render json: { status: result.ok? ? "ok" : "unavailable", checks: result.checks },
           status: result.ok? ? :ok : :service_unavailable
  end
end
