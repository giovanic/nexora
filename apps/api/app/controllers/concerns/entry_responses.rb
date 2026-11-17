# Answers for the Nutrition::Api calls that return a meal: its view, 404 for a meal or item that is not
# the person's, and the refusals with their status.
module EntryResponses
  REFUSALS = {
    "validation_failed" => :unprocessable_content,
    "entry_not_confirmable" => :conflict,
    "entry_not_editable" => :conflict
  }.freeze

  private

  def render_entry(result, status: :ok)
    return render_error(:not_found) if result == :not_found
    return render_error(REFUSALS.fetch(result.code), result.code, details: result.details) unless result.ok?

    render json: result.view, status:
  end
end
