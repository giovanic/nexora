# Specs tagged :object_storage talk to the local SeaweedFS from docker-compose, through the real S3Storage.
# Every other spec uses the MemoryStorage double that FoodAi.storage returns in the test environment.
RSpec.configure do |config|
  config.around(:each, :object_storage) do |example|
    previous = FoodAi.storage
    FoodAi.storage = FoodAi::Adapters::S3Storage.from_env(ensure_bucket: true)
    example.run
  ensure
    FoodAi.storage = previous
  end
end
