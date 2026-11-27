# Answers for the Goals::Api calls: 404 for a goal that is not the person's, and the refusals with their status.
module GoalResponses
  REFUSALS = {
    "validation_failed" => :unprocessable_content,
    "goal_not_active" => :conflict
  }.freeze

  private

  # Renders the result as JSON built by the block (the Data object by default), or the error it carries.
  def render_goal(result, status: :ok)
    return render_error(:not_found) if result == :not_found
    return render_error(REFUSALS.fetch(result.code), result.code, details: result.details) unless result.ok?

    render json: block_given? ? yield(result) : result.to_h.except(:created), status:
  end
end
