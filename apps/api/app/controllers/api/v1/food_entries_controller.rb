module Api
  module V1
    # A meal with its items, ranges and confidence, exactly as the clients show it; the history; the meal
    # registered by hand; its confirmation and its deletion. Another person's meal is a 404. The body can
    # carry a signed photo URL, so the response is never cached (no-store, see Authentication).
    class FoodEntriesController < ApplicationController
      include EntryResponses

      # Deleting a whole meal is erasure (LGPD art. 18): it must work after health_data is revoked.
      require_consent :health_data, except: :destroy

      ITEM_FIELDS = %i[catalog_item_id free_text_name grams_min grams_likely grams_max].freeze

      def show
        result = Nutrition::Api.entry(user_id: current_user_id, food_entry_id: params[:id])
        render_entry(result)
      end

      def index
        result = Nutrition::Api.list_entries(user_id: current_user_id, local_date: params[:local_date], cursor: params[:cursor], per_page: params[:per_page])
        return render_entry(result) unless result.ok?

        render json: { items: result.views, next_cursor: result.next_cursor }
      end

      def create
        result = Nutrition::Api.create_manual_entry(user_id: current_user_id, client_request_id: params[:client_request_id], meal_at: params[:meal_at],
                                                    items: items_param)
        render_entry(result, status: result.ok? && !result.created ? :ok : :created)
      end

      def confirm
        render_entry(Nutrition::Api.confirm_entry(user_id: current_user_id, food_entry_id: params[:id]))
      end

      def destroy
        return render_error(:not_found) if Nutrition::Api.delete_entry(user_id: current_user_id, food_entry_id: params[:id]) == :not_found

        head :no_content
      end

      private

      # The items as plain hashes, for Nutrition to check. Anything that is not a list of objects reaches it as is.
      def items_param
        raw = params[:items]
        return raw unless raw.is_a?(Array)

        raw.map { |item| item.is_a?(ActionController::Parameters) ? item.permit(*ITEM_FIELDS).to_h.symbolize_keys : item }
      end
    end
  end
end
