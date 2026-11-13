# Registrations are rebuilt on every code load, since the registries are
# reloaded with the code. Contexts add their own in a to_prepare block.
Rails.application.config.to_prepare do
  Shared::DataRegistry.register(
    context: "shared",
    tables: %w[outbox_events],
    exporter: Shared::Outbox.method(:export_user_data),
    eraser: Shared::Outbox.method(:erase_user_data)
  )
end
