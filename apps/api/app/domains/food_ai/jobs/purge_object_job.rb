module FoodAi
  # Deletes the stored object of a photo that is already marked deleted. Used when the deletion
  # could not run where the photo was discarded (inside a consumer's transaction, or storage down).
  # Safe to repeat.
  class PurgeObjectJob
    include Sidekiq::Job

    def perform(photo_id)
      photo = FoodPhoto.find_by(id: photo_id)
      return unless photo&.status == "deleted"

      FoodAi.storage.delete(key: photo.object_key)
    end
  end
end
