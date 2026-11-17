module FoodAi
  # The daily quota counts photos whose URL was issued (cost control), not meals. A photo
  # whose quota was refunded does not count. The caller holds the person's lock.
  module CheckAnalysisQuota
    # nil when there is room, otherwise the moment the day ends.
    def self.exceeded_until(user_id:, day_start:, day_end:)
      used = FoodPhoto.where(user_id:, authorized_at: day_start...day_end, quota_refunded_at: nil).count
      used >= Config.daily_quota ? day_end : nil
    end
  end
end
