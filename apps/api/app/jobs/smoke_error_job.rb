# Proves that a job failure reaches the error tracker. It never retries.
class SmokeErrorJob
  include Sidekiq::Job

  sidekiq_options retry: false, dead: false

  def perform
    raise Internal::SmokeError, "provoked job error"
  end
end
