module Api
  module V1
    # Consent per purpose of the signed-in person. Works without health_data,
    # since that is where it is given (design 4.5).
    class ConsentsController < ApplicationController
      STATUSES = { "outdated_version" => :conflict, "revocation_pending" => :conflict, "validation_failed" => :unprocessable_content }.freeze

      def index
        render json: { consents: Identity::Api.consents(user_id: current_user_id).map { |consent| serialize(consent) } }
      end

      def create
        fields = params.permit(:purpose, :version)
        result = Identity::Api.grant_consent(user_id: current_user_id, purpose: fields[:purpose], version: fields[:version],
                                             source: current_session.client)
        return render_refusal(result) if result == :not_found || !result.ok?

        render json: serialize(result), status: :created
      end

      def destroy
        return render_error(:not_found) unless Identity::Api.consent_purpose?(params[:purpose])

        result = Identity::Api.revoke_consent(user_id: current_user_id, purpose: params[:purpose], source: current_session.client)
        return render_refusal(result) unless result == true

        head :no_content
      end

      def text
        text = Identity::Api.consent_text(purpose: params[:purpose])
        return render_error(:not_found) unless text

        render json: { purpose: text.purpose, version: text.version, text: text.body }
      end

      private

      # :not_found only for an account deleted between the session check and here.
      def render_refusal(result)
        return render_error(:not_found) if result == :not_found

        render_error(STATUSES.fetch(result.code), result.code, details: result.details)
      end

      def serialize(consent)
        { purpose: consent.purpose, state: consent.state, current_version: consent.current_version,
          accepted_version: consent.accepted_version, decided_at: consent.decided_at&.iso8601 }
      end
    end
  end
end
