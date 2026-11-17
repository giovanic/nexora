module FoodAi
  # Daily (config/schedule.yml). Analyses (with raw_response) older than 90 days are deleted, and usage
  # records older than 90 days lose the link to the person and to the analysis but keep provider, model,
  # tokens and cost. Batches, safe to repeat. Counts only in the log.
  class AnalysisRetentionJob
    include Sidekiq::Job

    sidekiq_options retry: false

    PERIOD = 90.days
    BATCH = 1_000

    def perform
      cutoff = PERIOD.ago
      unlinked = 0
      UsageRecord.where(occurred_at: ...cutoff).where("user_id IS NOT NULL OR analysis_id IS NOT NULL").in_batches(of: BATCH) do |batch|
        unlinked += batch.update_all(user_id: nil, analysis_id: nil, updated_at: Time.current)
      end
      deleted = 0
      AnalysisResult.where(created_at: ...cutoff).in_batches(of: BATCH) do |batch|
        deleted += batch.delete_all
      end
      result = { analyses: deleted, usage_unlinked: unlinked }
      Sidekiq.logger.info("food analysis retention #{result.map { |name, count| "#{name}=#{count}" }.join(' ')}")
      result
    end
  end
end
