# Goals' tables in account export and deletion.
Rails.application.config.to_prepare do
  Shared::DataRegistry.register(
    context: "goals",
    tables: Goals::Api::USER_DATA_TABLES,
    exporter: Goals::Api.method(:export_user_data),
    eraser: Goals::Api.method(:erase_user_data)
  )
end
