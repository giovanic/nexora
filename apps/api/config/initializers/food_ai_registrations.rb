# FoodAi.storage, the configured object storage: a MemoryStorage double in the test environment,
# S3Storage elsewhere. Specs tagged :object_storage swap in the real S3Storage (spec/support/object_storage.rb).
# Defined here because the domain boundary check allows no file at the top of app/domains.
Rails.application.config.to_prepare do
  FoodAi.singleton_class.attr_accessor :storage
  FoodAi.storage = Rails.env.test? ? FoodAi::Adapters::MemoryStorage.new : FoodAi::Adapters::S3Storage.from_env

  # FoodAi's tables in account export and deletion. prompt_versions holds no person
  # (Shared::DataRegistry::TABLES_WITHOUT_USER_DATA).
  Shared::DataRegistry.register(
    context: "food_ai",
    tables: FoodAi::Api::USER_DATA_TABLES,
    exporter: FoodAi::Api.method(:export_user_data),
    eraser: FoodAi::Api.method(:erase_user_data)
  )
end
