module Health
  class ReadinessCheck
    # A dependency that accepts connections and never answers must not hang the
    # check, so every probe runs against this deadline.
    DEADLINE_SECONDS = 2

    Result = Data.define(:checks) do
      def ok?
        checks.values.all?("ok")
      end
    end

    def self.default
      new(database: database_probe, queue: queue_probe(Rails.configuration.x.queue_url))
    end

    def self.database_probe
      -> { ActiveRecord::Base.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") } }
    end

    def self.queue_probe(url)
      lambda do
        client = RedisClient.config(url:, connect_timeout: 0.5, read_timeout: 0.5, write_timeout: 0.5).new_client
        begin
          client.call("PING")
        ensure
          client.close
        end
      end
    end

    def initialize(database:, queue:)
      @probes = { database:, queue: }
    end

    def call
      deadline = monotonic_now + DEADLINE_SECONDS
      threads = @probes.transform_values { |probe| start(probe) }

      Result.new(checks: threads.transform_values { |thread| outcome(thread, deadline) })
    end

    private

    def start(probe)
      Thread.new do
        Thread.current.report_on_exception = false
        probe.call
        "ok"
      rescue StandardError
        "error"
      end
    end

    def outcome(thread, deadline)
      return thread.value if thread.join([ deadline - monotonic_now, 0 ].max)

      thread.kill
      "error"
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
