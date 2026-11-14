module Api
  module V1
    # Adds, corrects and removes the items of a meal. Each answers the whole meal, recalculated. A
    # correction creates a new item; the original stays stored out of sight. Another person's meal or
    # item is a 404. Item names are never logged (the parameters are filtered).
    class FoodEntryItemsController < ApplicationController
      include EntryResponses

      require_consent :health_data

      def create
        item = params.permit(:catalog_item_id, :free_text_name, :grams_min, :grams_likely, :grams_max).to_h.symbolize_keys
        render_entry(Nutrition::Api.add_item(user_id: current_user_id, food_entry_id: params[:id], item:), status: :created)
      end

      def update
        changes = params.permit(:grams_likely, :catalog_item_id).to_h.symbolize_keys
        render_entry(Nutrition::Api.correct_item(user_id: current_user_id, food_entry_id: params[:id], item_id: params[:item_id], changes:))
      end

      def destroy
        render_entry(Nutrition::Api.remove_item(user_id: current_user_id, food_entry_id: params[:id], item_id: params[:item_id]))
      end
    end
  end
end
