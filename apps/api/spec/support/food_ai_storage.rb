# FoodAi.storage is one global MemoryStorage, so each example gets a fresh one and nothing leaks between them.
# Examples tagged :object_storage keep the real S3Storage set by spec/support/object_storage.rb.
RSpec.configure do |config|
  config.before do |example|
    FoodAi.storage = FoodAi::Adapters::MemoryStorage.new unless example.metadata[:object_storage]
  end
end
