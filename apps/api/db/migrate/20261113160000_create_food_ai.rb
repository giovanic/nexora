# Food AI core: the photo (owner of the stored object), each analysis run, the cost per
# provider call and the registry of prompt versions.
#
# food_entry_id is a plain uuid reference, not a foreign key: meals belong to Nutrition and
# domains never join each other's tables. user_id references users, which are anonymized and
# never deleted. Closed lists live in CHECK constraints; the error_code list mirrors
# FoodAi::AnalysisResult::ERROR_CODES (provider error codes plus job-level codes).
class CreateFoodAi < ActiveRecord::Migration[8.1]
  ERROR_CODES = %w[
    timeout rate_limited provider_unavailable
    bad_request unauthorized model_unavailable unsupported_model
    not_an_object missing_field unexpected_field wrong_type out_of_range too_many_items invalid_text unknown_value forbidden_field refusal
    consent_revoked photo_missing
  ].freeze

  USAGE_PROVIDERS = %w[anthropic gemini openai fake].freeze
  USAGE_MODELS = %w[claude-haiku-5-5 claude-sonnet-5-5 gemini-3.8-flash gemini-3.5-flash-lite gpt-6-luna gpt-6.1-terra fake-1].freeze

  def change
    create_table :food_photos, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.uuid :food_entry_id
      t.string :client_request_id, null: false
      t.string :object_key, null: false
      t.string :content_type, null: false
      t.integer :byte_size
      t.string :status, null: false, default: "awaiting_upload"
      t.datetime :authorized_at, null: false
      t.datetime :analyzed_at
      t.datetime :deleted_at
      t.datetime :quota_refunded_at
      t.timestamps

      t.check_constraint "status IN ('awaiting_upload', 'stored', 'deleted')", name: "food_photos_status_known"
    end
    add_index :food_photos, :object_key, unique: true
    add_index :food_photos, %i[user_id client_request_id], unique: true
    add_index :food_photos, %i[user_id authorized_at], name: "index_food_photos_on_user_and_authorized_at"
    add_index :food_photos, %i[status authorized_at], name: "index_food_photos_on_status_and_authorized_at"
    add_index :food_photos, %i[status analyzed_at], name: "index_food_photos_on_status_and_analyzed_at"
    add_index :food_photos, :food_entry_id

    create_table :food_analysis_results, id: :uuid do |t|
      t.uuid :food_entry_id
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.references :photo, type: :uuid, null: false, foreign_key: { to_table: :food_photos, on_delete: :cascade }, index: false
      t.string :provider, null: false
      t.string :model, null: false
      t.string :prompt_version, null: false
      t.string :schema_version, null: false
      t.string :status, null: false, default: "running"
      t.jsonb :raw_response
      t.string :error_code
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps

      t.check_constraint "status IN ('running', 'succeeded', 'no_food', 'unreadable', 'failed', 'cancelled')",
                         name: "food_analysis_results_status_known"
      t.check_constraint "error_code IS NULL OR error_code IN (#{ERROR_CODES.map { |c| "'#{c}'" }.join(', ')})",
                         name: "food_analysis_results_error_code_known"
    end
    add_index :food_analysis_results, :food_entry_id
    add_index :food_analysis_results, %i[user_id started_at], name: "index_food_analysis_results_on_user_and_started_at"
    add_index :food_analysis_results, %i[prompt_version status], name: "index_food_analysis_results_on_prompt_and_status"
    # One live run per photo and prompt version: a retry after a failure or cancellation is
    # a new run, while two concurrent successful runs stay impossible.
    add_index :food_analysis_results, %i[photo_id prompt_version], unique: true,
              where: "status NOT IN ('failed', 'cancelled')", name: "index_food_analysis_results_one_live_run"

    create_table :ai_usage_records, id: :uuid do |t|
      t.references :analysis, type: :uuid, foreign_key: { to_table: :food_analysis_results, on_delete: :nullify }, index: true
      t.references :user, type: :uuid, foreign_key: true, index: false
      t.string :provider, null: false
      t.string :model, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.decimal :cost_usd, precision: 12, scale: 8, null: false, default: 0
      t.datetime :occurred_at, null: false
      t.timestamps

      t.check_constraint "input_tokens >= 0 AND output_tokens >= 0 AND cost_usd >= 0", name: "ai_usage_records_non_negative"
      # Usage rows outlive the account as cost only, so provider and model hold closed lists
      # (the priced models of FoodAi::Pricing, plus the test double) and no free text.
      t.check_constraint "provider IN (#{USAGE_PROVIDERS.map { |c| "'#{c}'" }.join(', ')})", name: "ai_usage_records_provider_known"
      t.check_constraint "model IN (#{USAGE_MODELS.map { |c| "'#{c}'" }.join(', ')})", name: "ai_usage_records_model_known"
    end
    add_index :ai_usage_records, %i[user_id occurred_at]
    add_index :ai_usage_records, :occurred_at

    create_table :prompt_versions, id: :uuid do |t|
      t.string :version, null: false
      t.string :schema_version, null: false
      t.string :body_ref, null: false
      t.datetime :activated_at
      t.timestamps
    end
    add_index :prompt_versions, :version, unique: true
  end
end
