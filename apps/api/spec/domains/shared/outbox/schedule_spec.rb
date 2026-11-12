require "rails_helper"

RSpec.describe "outbox schedule" do
  let(:schedule) { YAML.load_file(Rails.root.join("config/schedule.yml")) }

  it "is the schedule file Sidekiq loads" do
    expect(Sidekiq::Cron.configuration.cron_schedule_file).to eq(Rails.root.join("config/schedule.yml").to_s)
  end

  it "runs the publisher every minute, as a safety net for the enqueue after commit" do
    expect(schedule.fetch("outbox_publish")).to include("class" => "Shared::Outbox::PublishJob", "cron" => "* * * * *")
  end

  it "runs the reconciliation every hour" do
    expect(schedule.fetch("outbox_reconcile")).to include("class" => "Shared::Outbox::ReconcileJob", "cron" => "0 * * * *")
  end

  # Fugit is the parser sidekiq-cron uses; building a Sidekiq::Cron::Job would read Valkey.
  it "defines valid jobs" do
    schedule.each do |name, options|
      expect(Fugit::Cron.parse(options.fetch("cron"))).to be_present, "#{name}: invalid cron"
      expect(options.fetch("class").constantize).to include(Sidekiq::Job)
    end
  end
end
