require "sentry-ruby"
require "observability/error_scrubber"

module Observability
  module ErrorTracking
    # Stays inactive without a DSN, so tests and CI never send anything.
    def self.start(env = ENV)
      dsn = env["ERROR_TRACKING_DSN"].to_s.strip
      return false if dsn.empty?

      Sentry.init do |config|
        config.dsn = dsn
        config.before_send = ErrorScrubber
        collect_no_personal_data(config.data_collection)
      end
      true
    end

    def self.collect_no_personal_data(collection)
      collection.user_info = false
      collection.cookies = false
      collection.http_headers.request = false
      collection.http_headers.response = false
      collection.http_bodies = []
      collection.url_query_params = false
      collection.stack_frame_variables = false
      collection.frame_context_lines = 0
    end
    private_class_method :collect_no_personal_data
  end
end
