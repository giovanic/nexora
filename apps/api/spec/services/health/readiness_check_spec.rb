require "rails_helper"
require "socket"

RSpec.describe Health::ReadinessCheck do
  let(:healthy) { -> { true } }
  let(:failing) { -> { raise "connection refused to secret-host:5432" } }

  it "is ok when both probes succeed" do
    result = described_class.new(database: healthy, queue: healthy).call

    expect(result).to be_ok
    expect(result.checks).to eq(database: "ok", queue: "ok")
  end

  it "reports which dependency failed" do
    result = described_class.new(database: failing, queue: healthy).call

    expect(result).not_to be_ok
    expect(result.checks).to eq(database: "error", queue: "ok")
  end

  it "reports a probe that never returns as an error within the deadline" do
    hanging = -> { sleep 30 }

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = described_class.new(database: hanging, queue: healthy).call
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    expect(result.checks).to eq(database: "error", queue: "ok")
    expect(elapsed).to be < 3
  end

  describe ".queue_probe" do
    it "succeeds against the real queue service" do
      expect { described_class.queue_probe(Rails.configuration.x.queue_url).call }.not_to raise_error
    end

    it "fails when the service refuses connections" do
      expect { described_class.queue_probe("redis://127.0.0.1:1/0").call }.to raise_error(StandardError)
    end

    it "fails quickly when the service accepts and never replies" do
      server = TCPServer.new("127.0.0.1", 0)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect { described_class.queue_probe("redis://127.0.0.1:#{server.addr[1]}/0").call }.to raise_error(StandardError)
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 3
    ensure
      server&.close
    end
  end

  describe ".database_probe" do
    it "succeeds against the real database" do
      expect { described_class.database_probe.call }.not_to raise_error
    end
  end
end
