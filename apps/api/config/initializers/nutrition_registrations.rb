# Nutrition's tables in account export and deletion.
Rails.application.config.to_prepare do
  Shared::DataRegistry.register(
    context: "nutrition",
    tables: Nutrition::Api::USER_DATA_TABLES,
    exporter: Nutrition::Api.method(:export_user_data),
    eraser: Nutrition::Api.method(:erase_user_data)
  )
end
