Sidekiq.configure_client do |config|
  config.redis = { url: Rails.configuration.x.queue_url }
end

Sidekiq.configure_server do |config|
  config.redis = { url: Rails.configuration.x.queue_url }
end
