# FoodAi.storage, the configured object storage: a MemoryStorage double in the test environment,
# S3Storage elsewhere. Specs tagged :object_storage swap in the real S3Storage (spec/support/object_storage.rb).
# Defined here because the domain boundary check allows no file at the top of app/domains.
Rails.application.config.to_prepare do
  FoodAi.singleton_class.attr_accessor :storage
  FoodAi.storage = Rails.env.test? ? FoodAi::Adapters::MemoryStorage.new : FoodAi::Adapters::S3Storage.from_env
end
