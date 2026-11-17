module FoodAi
  # Daily (config/schedule.yml). Sums the month's cost; above FOOD_AI_MONTHLY_ALERT_USD it sends one
  # Sentry event with the total and the limit, once per month and per limit (a marker in Rails.cache,
  # written atomically before the capture, and removed if the capture fails). No person data: the total spans everyone.
  class SpendAlertJob
    include Sidekiq::Job

    sidekiq_options retry: false

    class LimitExceeded < StandardError; end

    def perform
      now = Time.current
      total = UsageRecord.where(occurred_at: now.beginning_of_month..now.end_of_month).sum(:cost_usd)
      limit = Config.monthly_alert_usd
      return false unless total > limit

      marker = "food_ai/spend_alert/#{now.strftime('%Y-%m')}/#{limit.to_s('F')}"
      return false unless Rails.cache.write(marker, true, unless_exist: true, expires_in: 62.days)

      begin
        Sentry.capture_exception(LimitExceeded.new, tags: { food_ai_spend_usd: total.to_s("F"), food_ai_limit_usd: limit.to_s("F") })
      rescue StandardError
        Rails.cache.delete(marker) # an alert that did not leave must not be lost for the whole month
        raise
      end
      true
    end
  end
end
