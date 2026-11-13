module Identity
  # Hourly (config/schedule.yml). An account must be erased within 24 hours of
  # the request (design 4.4): every unfinished deletion gets its erasure
  # enqueued again, a safety net for an enqueue lost after the commit, and one
  # past the deadline raises an alert. The alert names only the deletion id,
  # never the person.
  class DeletionDeadlineJob
    include Sidekiq::Job

    sidekiq_options retry: false

    DEADLINE = 24.hours

    # Raised for the error tracker only, never thrown: it carries no message.
    class Overdue < StandardError; end

    def perform
      AccountDeletion.where(completed_at: nil).order(:requested_at).pluck(:id, :requested_at).each do |id, requested_at|
        alert(id) if requested_at <= DEADLINE.ago
        EraseAccountJob.perform_async(id)
      end
    end

    private

    def alert(id)
      Sentry.capture_exception(Overdue.new, tags: { account_deletion: id })
    end
  end
end
