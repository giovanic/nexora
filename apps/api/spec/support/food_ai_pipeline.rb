require "support/food_ai_consent"
require "support/food_ai_adapter"
require "support/image_fixtures"

# A person with consent and a stored photo (with EXIF and GPS) linked to a meal, for the pipeline specs.
module FoodAiPipeline
  def self.included(base)
    base.include FoodAiConsent
    base.include ActiveSupport::Testing::TimeHelpers
  end

  def create_user(tag = SecureRandom.hex(4))
    Identity::User.create!(email: "pipe-#{tag}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current)
  end

  def create_photo(user:, status: "stored", bytes: ImageFixtures.jpeg_with_gps, content_type: "image/jpeg", store: true)
    entry_id = SecureRandom.uuid
    photo = FoodAi::FoodPhoto.create!(
      user_id: user.id, food_entry_id: entry_id, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}",
      content_type:, byte_size: bytes.bytesize, status:, authorized_at: Time.current
    )
    FoodAi.storage.write(key: photo.object_key, bytes:, content_type:) if store
    photo
  end

  def run_job(photo, *args) = FoodAi::AnalyzeJob.new.perform(photo.id, *args)

  # Runs the job, then each retry it schedules, in order, and returns the delays it asked for.
  def run_until_settled(photo)
    delays = []
    queue = [ [] ]
    allow(FoodAi::AnalyzeJob).to receive(:perform_in) { |delay, _id, *args| delays << delay; queue << args }
    run_job(photo, *queue.shift) until queue.empty?
    delays
  end

  def completed_events(user_id: nil)
    scope = Shared::Outbox::Event.where(name: "food_analysis.completed").order(:occurred_at, :id)
    (user_id ? scope.where(user_id:) : scope).map(&:payload)
  end

  def run_publisher_now = Shared::Outbox::PublishJob.new.perform
end
