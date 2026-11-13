# Periodic jobs. Sidekiq without Enterprise has no scheduler, so sidekiq-cron
# loads config/schedule.yml when a worker starts (design of Phase 02, 4.10).
Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = Rails.root.join("config/schedule.yml").to_s
end
