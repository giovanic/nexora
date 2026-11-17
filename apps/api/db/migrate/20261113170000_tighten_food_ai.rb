# Review fixes on CreateFoodAi (already committed, so a new migration):
# - a plain index on food_analysis_results.photo_id: the partial unique index cannot serve the
#   ON DELETE CASCADE from food_photos (nor lookups of every run of a photo);
# - ai_usage_records no longer lists provider and model in CHECKs (the test double does not
#   belong in the production schema, and FoodAi::Pricing already refuses unknown models);
# - the error_code list gains invalid_encoding and duplicate_value.
class TightenFoodAi < ActiveRecord::Migration[8.1]
  OLD_CODES = %w[
    timeout rate_limited provider_unavailable
    bad_request unauthorized model_unavailable unsupported_model
    not_an_object missing_field unexpected_field wrong_type out_of_range too_many_items invalid_text unknown_value forbidden_field refusal
    consent_revoked photo_missing
  ].freeze
  NEW_CODES = (OLD_CODES + %w[invalid_encoding duplicate_value]).freeze
  PROVIDERS = %w[anthropic gemini openai fake].freeze
  MODELS = %w[claude-haiku-5-5 claude-sonnet-5-5 gemini-3.8-flash gemini-3.5-flash-lite gpt-6-luna gpt-6.1-terra fake-1].freeze

  def change
    add_index :food_analysis_results, :photo_id, name: "index_food_analysis_results_on_photo_id"

    remove_check_constraint :ai_usage_records, "provider IN (#{list(PROVIDERS)})", name: "ai_usage_records_provider_known"
    remove_check_constraint :ai_usage_records, "model IN (#{list(MODELS)})", name: "ai_usage_records_model_known"

    remove_check_constraint :food_analysis_results, "error_code IS NULL OR error_code IN (#{list(OLD_CODES)})", name: "food_analysis_results_error_code_known"
    add_check_constraint :food_analysis_results, "error_code IS NULL OR error_code IN (#{list(NEW_CODES)})", name: "food_analysis_results_error_code_known"
  end

  private

  def list(values) = values.map { |value| "'#{value}'" }.join(", ")
end
