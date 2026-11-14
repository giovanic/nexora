module FoodAi
  # Recovery of a meal stuck in processing (a job lost with its process or with Redis, or an event whose
  # analysis was not found). Called by Nutrition for a meal that has been processing for a long time.
  # It never calls the provider itself: it enqueues AnalyzeJob, whose claim (unique index on photo and
  # prompt version, stale takeover after RunAnalysis::STALE_AFTER) keeps it to one call per photo and prompt.
  #
  # Answers, in this order:
  #  - Errors photo_missing: not the person's photo or meal, or deleted/not uploaded, with no result to deliver;
  #  - :republished: a concluded analysis for the current prompt exists, and its completed event is sent
  #    again (consumers are idempotent). Not while the earlier event still waits in the outbox;
  #  - Errors analysis_failed: the last run ended in failure (the quota unit was refunded), so the meal fails;
  #  - :running: a run that is not stale is in progress;
  #  - :enqueued: stored, with no live analysis or only a stale one.
  module ResumeAnalysis
    CONCLUDED = RunAnalysis::LIVE_STATUSES

    def self.call(user_id:, photo_id:, food_entry_id:)
      photo = FoodPhoto.find_by(user_id:, id: photo_id)
      return missing unless photo && [ nil, food_entry_id ].include?(photo.food_entry_id)

      prompt = PromptCatalog.current
      analyses = AnalysisResult.where(photo_id: photo.id, prompt_version: prompt.version).where.not(status: %w[failed cancelled])
      concluded = analyses.find_by(status: CONCLUDED)
      return republish(photo, concluded, food_entry_id) if concluded
      return missing unless photo.status == "stored"
      return Api::Errors.new(code: "analysis_failed") if photo.quota_refunded_at

      running = analyses.find_by(status: "running")
      return :running if running && running.updated_at >= RunAnalysis::STALE_AFTER.ago

      AnalyzeJob.perform_async(photo.id)
      :enqueued
    end

    def self.republish(photo, analysis, food_entry_id)
      outcome = RunAnalysis::OUTCOMES.fetch(analysis.status)
      FoodPhoto.transaction do
        next if Shared::Outbox.undelivered?(name: "food_analysis.completed", user_id: photo.user_id, payload: { analysis_id: analysis.id, outcome: })

        RunAnalysis.publish_completed(user_id: photo.user_id, analysis_id: analysis.id, food_entry_id:, outcome:)
      end
      :republished
    end

    def self.missing = Api::Errors.new(code: "photo_missing")
    private_class_method :republish, :missing
  end
end
