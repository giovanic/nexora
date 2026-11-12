require "tempfile"

# Runs a real `sidekiq` process, so tests prove work crosses the queue service
# instead of exercising Sidekiq's in-process testing mode. Jobs wait in the
# queue while it boots, so callers only need to poll for the result.
module SidekiqProcess
  def self.with
    log = Tempfile.new("sidekiq-process")
    pid = spawn(
      { "RAILS_ENV" => "test" },
      "bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml",
      chdir: Rails.root.to_s, out: log.path, err: log.path
    )
    yield log
  ensure
    if pid
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
    log&.close!
  end
end
