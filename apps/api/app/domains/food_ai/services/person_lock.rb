module FoodAi
  # The person's advisory lock (until the end of the transaction): the quota is checked and changed
  # under it, by a new upload and by a new request for the analysis of a failed photo alike.
  module PersonLock
    def self.call(user_id)
      FoodPhoto.connection.execute(FoodPhoto.sanitize_sql([ "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))::text", "food_photo:#{user_id}" ]))
    end
  end
end
