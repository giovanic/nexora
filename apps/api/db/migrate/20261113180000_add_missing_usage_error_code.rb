# InvalidOutputError gains missing_usage (a 200 answer without usable token counts), so the
# error_code CHECK on food_analysis_results gains it too. Reversible.
class AddMissingUsageErrorCode < ActiveRecord::Migration[8.1]
  OLD_CODES = %w[
    timeout rate_limited provider_unavailable
    bad_request unauthorized model_unavailable unsupported_model
    not_an_object missing_field unexpected_field wrong_type out_of_range too_many_items invalid_text unknown_value forbidden_field refusal
    consent_revoked photo_missing invalid_encoding duplicate_value
  ].freeze
  NEW_CODES = (OLD_CODES + %w[missing_usage]).freeze

  def change
    remove_check_constraint :food_analysis_results, "error_code IS NULL OR error_code IN (#{list(OLD_CODES)})", name: "food_analysis_results_error_code_known"
    add_check_constraint :food_analysis_results, "error_code IS NULL OR error_code IN (#{list(NEW_CODES)})", name: "food_analysis_results_error_code_known"
  end

  private

  def list(values) = values.map { |value| "'#{value}'" }.join(", ")
end
