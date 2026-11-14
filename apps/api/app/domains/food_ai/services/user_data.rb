module FoodAi
  # FoodAi's part of account export and deletion, through Shared::DataRegistry.
  module UserData
    def self.export(user_id)
      {
        photos: FoodPhoto.where(user_id:).order(:authorized_at, :id).map do |photo|
          photo.slice(:id, :content_type, :byte_size, :status, :authorized_at, :analyzed_at, :deleted_at).symbolize_keys
        end,
        analyses: AnalysisResult.where(user_id:).order(:started_at, :id).map do |analysis|
          analysis.slice(:id, :provider, :model, :prompt_version, :schema_version, :status, :error_code, :started_at, :finished_at).symbolize_keys
        end,
        usage: UsageRecord.where(user_id:).order(:occurred_at, :id).map do |usage|
          { id: usage.id, provider: usage.provider, model: usage.model, input_tokens: usage.input_tokens,
            output_tokens: usage.output_tokens, cost_usd: usage.cost_usd.to_s, occurred_at: usage.occurred_at }
        end
      }
    end

    # Safe to run again. Stored objects go first (an external call, outside any transaction),
    # so a failure leaves the rows for the next attempt to find the keys. Usage records stay
    # as cost only, unlinked from the person and from the analysis (retention table).
    def self.erase(user_id)
      FoodPhoto.where(user_id:).where.not(status: "deleted").find_each { |photo| FoodAi.storage.delete(key: photo.object_key) }
      ApplicationRecord.transaction do
        UsageRecord.where(user_id:).update_all(user_id: nil, analysis_id: nil)
        AnalysisResult.where(user_id:).delete_all
        FoodPhoto.where(user_id:).delete_all
      end
    end
  end
end
