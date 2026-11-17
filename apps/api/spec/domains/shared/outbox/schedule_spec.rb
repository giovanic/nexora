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

  it "watches the 24-hour deadline of account deletions every hour" do
    expect(schedule.fetch("account_deletion_deadline")).to include("class" => "Identity::DeletionDeadlineJob", "cron" => "0 * * * *")
  end

  it "runs both retention jobs daily" do
    expect(schedule.fetch("outbox_cleanup")).to include("class" => "Shared::Outbox::CleanupJob", "cron" => "30 3 * * *")
    expect(schedule.fetch("identity_retention")).to include("class" => "Identity::RetentionJob", "cron" => "45 3 * * *")
  end

  it "schedules the food retention, abandoned upload, spend alert and recovery routines" do
    expect(schedule.fetch("food_photo_retention")).to include("class" => "FoodAi::PhotoRetentionJob", "cron" => "15 4 * * *")
    expect(schedule.fetch("food_abandoned_entries")).to include("class" => "Nutrition::AbandonedEntriesJob", "cron" => "5 * * * *")
    expect(schedule.fetch("food_analysis_retention")).to include("class" => "FoodAi::AnalysisRetentionJob", "cron" => "30 4 * * *")
    expect(schedule.fetch("food_ai_spend_alert")).to include("class" => "FoodAi::SpendAlertJob", "cron" => "0 6 * * *")
    expect(schedule.fetch("food_stuck_entries")).to include("class" => "Nutrition::StuckEntriesJob", "cron" => "*/10 * * * *")
  end

  # Fugit is the parser sidekiq-cron uses; building a Sidekiq::Cron::Job would read Valkey.
  it "defines valid jobs" do
    schedule.each do |name, options|
      expect(Fugit::Cron.parse(options.fetch("cron"))).to be_present, "#{name}: invalid cron"
      expect(options.fetch("class").constantize).to include(Sidekiq::Job)
    end
  end
end
