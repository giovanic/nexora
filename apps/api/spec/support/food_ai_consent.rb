# A consent version of food_photo_ai that names an operator and a region, which the
# real v1 does not. It exists only in the test environment: it stubs the constants of
# Identity::ConsentTexts and the environment of the active provider, and never touches
# config/consents or production configuration. Granting a version does not read its text.
module FoodAiConsent
  OPERATOR = "test-operator".freeze
  REGION = "test-region".freeze
  VERSION = 2

  def use_operator_consent_version(operator: OPERATOR, region: REGION, configured_operator: operator, configured_region: region)
    stub_const("Identity::ConsentTexts::CURRENT_VERSIONS", Identity::ConsentTexts::CURRENT_VERSIONS.merge("food_photo_ai" => VERSION))
    stub_const("Identity::ConsentTexts::TERMS",
               Identity::ConsentTexts::TERMS.merge("food_photo_ai" => Identity::ConsentTexts::TERMS.fetch("food_photo_ai").merge(VERSION => { operator:, region: })))
    configure_food_ai_env("FOOD_AI_OPERATOR" => configured_operator, "FOOD_AI_REGION" => configured_region)
  end

  def configure_food_ai_env(values)
    @food_ai_env = (@food_ai_env || {}).merge(values)
    allow(ENV).to receive(:[]).and_call_original
    @food_ai_env.each { |name, value| allow(ENV).to receive(:[]).with(name).and_return(value) }
  end

  def grant_food_photo_ai(user_id, version: VERSION)
    Identity::Api.grant_consent(user_id:, purpose: "health_data", version: Identity::ConsentTexts.current_version("health_data"))
    Identity::Api.grant_consent(user_id:, purpose: "food_photo_ai", version:)
  end
end

RSpec.configure { |config| config.include FoodAiConsent }
