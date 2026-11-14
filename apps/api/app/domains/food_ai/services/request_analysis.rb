module FoodAi
  # Starts the analysis of an uploaded photo: consent, then the object in storage against what was
  # authorized (size and type), then the photo is marked stored and the job is enqueued. A failed
  # meal asks again for the same photo, which clears its quota refund (the unit counts again).
  # The storage is asked outside any transaction.
  module RequestAnalysis
    def self.call(user_id:, photo_id:, food_entry_id:)
      photo = FoodPhoto.find_by(user_id:, id: photo_id)
      return error("not_uploaded") if photo.nil? || photo.status == "deleted" || (photo.food_entry_id && photo.food_entry_id != food_entry_id)

      code = ConsentGate.check(user_id:)
      return error(code) if code

      info = FoodAi.storage.head(key: photo.object_key)
      return error("not_uploaded") if info.nil?

      mismatch = mismatch_code(photo, info)
      return error("invalid_photo", details: [ { field: "photo", code: mismatch } ]) if mismatch

      return error("not_uploaded") unless mark_stored(photo, food_entry_id)

      AnalyzeJob.perform_async(photo.id)
      :enqueued
    end

    def self.mismatch_code(photo, info)
      return "size_mismatch" unless info.byte_size == photo.byte_size
      return "type_mismatch" unless info.content_type.to_s.split(";").first == photo.content_type

      nil
    end

    # False when the photo was deleted meanwhile.
    def self.mark_stored(photo, food_entry_id)
      FoodPhoto.transaction do
        locked = FoodPhoto.lock.find(photo.id)
        next false if locked.status == "deleted"

        locked.update!(status: "stored", food_entry_id:, quota_refunded_at: nil)
        true
      end
    end

    def self.error(code, details: [])
      Api::Errors.new(code:, details:)
    end
    private_class_method :mismatch_code, :mark_stored, :error
  end
end
