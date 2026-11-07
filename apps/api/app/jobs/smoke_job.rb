# Proves that work enqueued by the API crosses the queue service and reaches a
# worker. Records only a short-lived marker, and nothing in PostgreSQL.
class SmokeJob
  include Sidekiq::Job

  MARKER_TTL_SECONDS = 60

  def self.done?(id)
    Sidekiq.redis { |connection| connection.call("EXISTS", marker(id)) } == 1
  end

  def self.marker(id)
    "smoke:#{id}"
  end

  def perform(id)
    Sidekiq.redis { |connection| connection.call("SET", self.class.marker(id), "done", "EX", MARKER_TTL_SECONDS) }
  end
end
