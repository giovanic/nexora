module FoodAi
  # What the environment says about Food AI, read on each call so the process never
  # keeps a stale copy. Values are never logged.
  module Config
    DEFAULT_DAILY_QUOTA = 20

    class << self
      def operator = present(ENV["FOOD_AI_OPERATOR"])
      def region = present(ENV["FOOD_AI_REGION"])
      def provider = present(ENV["FOOD_AI_PROVIDER"])
      def model = present(ENV["FOOD_AI_MODEL"])

      # Authorizations per person and local day. An invalid value falls back to the default.
      def daily_quota
        quota = Integer(ENV["FOOD_AI_DAILY_QUOTA"].to_s, 10, exception: false)
        quota&.positive? ? quota : DEFAULT_DAILY_QUOTA
      end

      # Names of the settings that do not match the consent text in force, never their values.
      # Only when a provider is configured: without one, uploads are refused by the gate.
      def operator_mismatch
        return [] if present(ENV["FOOD_AI_PROVIDER"]).nil?

        terms = Identity::Api.consent_terms(purpose: "food_photo_ai")
        mismatched = []
        mismatched << "FOOD_AI_OPERATOR" if operator.nil? || operator != terms.operator
        mismatched << "FOOD_AI_REGION" if region.nil? || region != terms.region
        mismatched
      end

      def verify_operator!
        mismatched = operator_mismatch
        return if mismatched.empty?

        raise "Configuração de Food AI não bate com a versão vigente do consentimento food_photo_ai: #{mismatched.join(', ')}"
      end

      private

      def present(value)
        value.to_s.strip.then { |text| text.empty? ? nil : text }
      end
    end
  end
end
