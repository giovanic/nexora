module Api
  module V1
    # Search of the food catalog, for correcting a meal. The term travels in the JSON body,
    # never in the URL, and is filtered from the logs. The catalog is reference data and the
    # term is not stored, but what a person looks up is about their food, so it needs health_data.
    class FoodsController < ApplicationController
      require_consent :health_data

      def search
        arguments = { term: params[:term], page: params.fetch(:page, 1) }
        arguments[:per_page] = params[:per_page] if params.key?(:per_page)
        invalid = FoodCatalog::Api.search_errors(**arguments)
        return render_error(:unprocessable_content, "validation_failed", details: invalid) if invalid.any?

        result = FoodCatalog::Api.search(**arguments)
        render json: { items: result.items.map(&:to_h), next_page: result.next_page }
      end
    end
  end
end
