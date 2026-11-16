# FoodAi.storage, the configured object storage: a MemoryStorage double in the test environment,
# S3Storage elsewhere. Specs tagged :object_storage swap in the real S3Storage (spec/support/object_storage.rb).
# Defined here because the domain boundary check allows no file at the top of app/domains.
Rails.application.config.to_prepare do
  FoodAi.singleton_class.attr_accessor :storage
  FoodAi.storage = Rails.env.test? ? FoodAi::Adapters::MemoryStorage.new : FoodAi::Adapters::S3Storage.from_env

  # The real adapter for a provider and model, with the key read from the environment. A missing
  # key or an unpriced model raises a coded PermanentProviderError (never the key itself).
  adapters = {
    "anthropic" => [ FoodAi::Adapters::AnthropicAdapter, "ANTHROPIC_API_KEY" ],
    "gemini" => [ FoodAi::Adapters::GeminiAdapter, "GEMINI_API_KEY" ],
    "openai" => [ FoodAi::Adapters::OpenaiAdapter, "OPENAI_API_KEY" ]
  }.freeze

  FoodAi.define_singleton_method(:adapter_for) do |provider:, model:, env: ENV, transport: FoodAi::Adapters::HttpTransport.new|
    klass, key_name = adapters[provider.to_s]
    raise FoodAi::PermanentProviderError, "unsupported_model" unless klass && FoodAi::Pricing::TABLE.key?([ provider.to_s, model.to_s ])

    api_key = env[key_name].to_s.strip
    raise FoodAi::PermanentProviderError, "unauthorized" if api_key.empty?

    klass.new(api_key: api_key, model: model, transport: transport)
  end

  # The adapter of the active provider (FOOD_AI_PROVIDER, FOOD_AI_MODEL). Specs assign a double.
  FoodAi.singleton_class.attr_writer :adapter
  FoodAi.define_singleton_method(:adapter) do
    @adapter || FoodAi.adapter_for(provider: ENV["FOOD_AI_PROVIDER"].to_s.strip, model: ENV["FOOD_AI_MODEL"].to_s.strip)
  end

  # A revoked food_photo_ai consent discards the photos not analyzed yet and tells their meals.
  Shared::Outbox.subscribe("consent.revoked", consumer: "food_ai.cancel_on_revocation") { |event| FoodAi::CancelOnRevocation.call(event) }

  # A deleted meal takes its photo, analyses and object with it, even if the process died after the commit.
  Shared::Outbox.subscribe("food_entry.deleted", consumer: "food_ai.erase_on_entry_deleted") { |event| FoodAi::EraseOnEntryDeleted.call(event) }

  # FoodAi's tables in account export and deletion. prompt_versions holds no person
  # (Shared::DataRegistry::TABLES_WITHOUT_USER_DATA).
  Shared::DataRegistry.register(
    context: "food_ai",
    tables: FoodAi::Api::USER_DATA_TABLES,
    exporter: FoodAi::Api.method(:export_user_data),
    eraser: FoodAi::Api.method(:erase_user_data)
  )
end
