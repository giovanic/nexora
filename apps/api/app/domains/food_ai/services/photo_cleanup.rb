module FoodAi
  # What FoodAi does when Nutrition lets go of a photo or a meal, and what it tells Nutrition
  # about an analysis. Objects go first (outside any transaction, safe to repeat), then the rows.
  module PhotoCleanup
    # The meal was deleted: object, photo and analyses go. The photo row stays as deleted, so a job
    # still running finds it and drops its result (the cost is kept, unlinked). Another person's
    # photo is never touched.
    # If the object cannot be deleted now, the photo is still marked deleted and PurgeObjectJob retries
    # the object (by photo id: the key never goes to the queue or a log). photo_id also finds a photo the
    # meal points to that does not point back to it yet.
    def self.erase_for_entry(user_id:, food_entry_id:, photo_id: nil)
      photos = FoodPhoto.where(user_id:)
      photos = photo_id ? photos.where(food_entry_id:).or(photos.where(id: photo_id)) : photos.where(food_entry_id:)
      photos.find_each do |photo|
        object_deleted = delete_object(photo)
        FoodPhoto.transaction do
          locked = FoodPhoto.lock.find(photo.id)
          analysis_ids = AnalysisResult.where(photo_id: photo.id).pluck(:id)
          UsageRecord.where(analysis_id: analysis_ids).update_all(analysis_id: nil, updated_at: Time.current)
          AnalysisResult.where(id: analysis_ids).delete_all
          locked.update!(status: "deleted", deleted_at: locked.deleted_at || Time.current) unless locked.status == "deleted"
        end
        PurgeObjectJob.perform_async(photo.id) unless object_deleted
      end
      nil
    end

    # true when the object is gone; false when storage failed (the error is not kept: it may name the key).
    def self.delete_object(photo)
      FoodAi.storage.delete(key: photo.object_key)
      true
    rescue StandardError
      false
    end
    private_class_method :delete_object

    # :discarded, :in_use (an analysis exists or is running) or :not_found, also for another person's photo.
    def self.discard_photo(user_id:, photo_id:)
      photo = FoodPhoto.find_by(user_id:, id: photo_id)
      return :not_found unless photo
      return :in_use if AnalysisResult.where(photo_id: photo.id, status: %w[running succeeded no_food unreadable]).exists?

      FoodAi.storage.delete(key: photo.object_key)
      FoodPhoto.transaction do
        locked = FoodPhoto.lock.find(photo.id)
        locked.update!(status: "deleted", deleted_at: Time.current) unless locked.status == "deleted"
      end
      :discarded
    end

    # AnalysisInfo, or :not_found.
    def self.analysis_info(analysis_id)
      analysis = AnalysisResult.find_by(id: analysis_id)
      return :not_found unless analysis

      raw = analysis.raw_response || {}
      Api::AnalysisInfo.new(id: analysis.id, status: analysis.status, items: Array(raw["items"]).map { |item| item_info(item) },
                            note_codes: Array(raw["note_codes"]))
    end

    def self.item_info(item)
      portion = item.fetch("portion")
      ItemInfo.new(name: item["name"], preparation: item["preparation"], confidence: item["confidence"], grams_min: portion["grams_min"],
                   grams_likely: portion["grams_likely"], grams_max: portion["grams_max"], household_measure: portion["household_measure"],
                   hidden_ingredients_possible: item["hidden_ingredients_possible"])
    end
    private_class_method :item_info
  end
end
