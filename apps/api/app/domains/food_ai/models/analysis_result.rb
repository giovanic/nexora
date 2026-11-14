module FoodAi
  # One run of the analysis pipeline. error_code is a closed list: provider error codes plus
  # job-level ones, never provider text. The partial unique index on (photo_id, prompt_version)
  # leaves failed and cancelled runs out, so a retry is a new run.
  class AnalysisResult < ApplicationRecord
    self.table_name = "food_analysis_results"

    STATUSES = %w[running succeeded no_food unreadable failed cancelled].freeze
    JOB_ERROR_CODES = %w[consent_revoked photo_missing invalid_photo internal_error].freeze
    ERROR_CODES = (TransientProviderError::CODES + PermanentProviderError::CODES + InvalidOutputError::CODES + JOB_ERROR_CODES).freeze

    belongs_to :photo, class_name: "FoodAi::FoodPhoto"

    validates :status, inclusion: { in: STATUSES }
    validates :error_code, inclusion: { in: ERROR_CODES }, allow_nil: true
    validates :provider, :model, :prompt_version, :schema_version, :started_at, presence: true
  end
end
