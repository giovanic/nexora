module FoodAi
  # The consent that must stand before a photo leaves for a provider: granted for the version in
  # force, and that version names the operator and region this deployment really uses.
  module ConsentGate
    # nil when the photo may go, otherwise the error code.
    def self.check(user_id:)
      consent = Identity::Api.consent(user_id:, purpose: "food_photo_ai")
      return "consent_required" unless %w[granted outdated].include?(consent.state)
      return "consent_operator_mismatch" unless consent.state == "granted"

      terms = Identity::Api.consent_terms(purpose: "food_photo_ai")
      same = Config.operator && Config.region && Config.operator == terms.operator && Config.region == terms.region
      same ? nil : "consent_operator_mismatch"
    end
  end
end
