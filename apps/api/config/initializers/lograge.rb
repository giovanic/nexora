require "observability/filtered_path"

Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Raw.new

  # Parameters are never logged, and an exception message can carry user data,
  # so the line records only the exception class. A path segment with a
  # filtered name, such as a reset token, is hidden as well.
  config.lograge.custom_options = lambda do |event|
    {
      path: Observability::FilteredPath.call(event.payload[:request], event.payload[:path]),
      request_id: event.payload[:request]&.request_id,
      duration_ms: event.duration&.round(2),
      error: event.payload[:exception]&.first
    }.compact
  end
end
