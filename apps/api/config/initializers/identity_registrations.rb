# Identity's tables in account export and deletion (design 4.4).
Rails.application.config.to_prepare do
  Shared::DataRegistry.register(
    context: "identity",
    tables: Identity::Api::USER_DATA_TABLES,
    exporter: Identity::Api.method(:export_user_data),
    eraser: Identity::Api.method(:erase_user_data)
  )
end
