# The analysis pipeline records two more job-level codes: invalid_photo (the stored photo failed
# normalization) and internal_error (an unexpected failure that exhausted the job retries).
# So the error_code CHECK on food_analysis_results gains them. Reversible.
class AddPipelineErrorCodes < ActiveRecord::Migration[8.1]
  OLD_CODES = %w[
    timeout rate_limited provider_unavailable
    bad_request unauthorized model_unavailable unsupported_model
    not_an_object missing_field unexpected_field wrong_type out_of_range too_many_items invalid_text unknown_value forbidden_field refusal
    consent_revoked photo_missing invalid_encoding duplicate_value missing_usage
  ].freeze
  NEW_CODES = (OLD_CODES + %w[invalid_photo internal_error]).freeze

  def change
    remove_check_constraint :food_analysis_results, "error_code IS NULL OR error_code IN (#{list(OLD_CODES)})", name: "food_analysis_results_error_code_known"
    add_check_constraint :food_analysis_results, "error_code IS NULL OR error_code IN (#{list(NEW_CODES)})", name: "food_analysis_results_error_code_known"
  end

  private

  def list(values) = values.map { |value| "'#{value}'" }.join(", ")
end
