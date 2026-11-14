module FoodAi
  # Runs one step of the analysis of a photo (RunAnalysis). Only the photo identifier and the
  # attempt counters travel in the job. A failure the provider reports (transient, invalid output)
  # is retried by scheduling this job again with a delay, and the run it ends is recorded, so the
  # attempts are counted once. Sidekiq's own retries only cover unexpected errors, and when they run
  # out the analysis ends as failed.
  class AnalyzeJob
    include Sidekiq::Job

    sidekiq_options retry: 3
    sidekiq_retries_exhausted { |job, _error| RunAnalysis.give_up(photo_id: job["args"].first) }

    def perform(photo_id, transient_attempts = 0, invalid_attempts = 0)
      step = RunAnalysis.call(photo_id:, transient_attempts:, invalid_attempts:)
      self.class.perform_in(step.delay, photo_id, step.transient_attempts, step.invalid_attempts) if step
    end
  end
end
