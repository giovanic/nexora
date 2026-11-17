require "rails_helper"
require "support/food_ai_consent"

RSpec.describe "consent terms" do
  it "binds v1 of food_photo_ai to no operator and no region" do
    terms = Identity::Api.consent_terms(purpose: "food_photo_ai")

    expect(terms).to eq(Identity::Api::ConsentTerms.new(version: 1, operator: nil, region: nil))
  end

  it "answers the operator and region of the version in force" do
    use_operator_consent_version

    expect(Identity::Api.consent_terms(purpose: "food_photo_ai")).to eq(
      Identity::Api::ConsentTerms.new(version: 2, operator: FoodAiConsent::OPERATOR, region: FoodAiConsent::REGION)
    )
  end

  it "has no operator for purposes that send nothing to a provider" do
    expect(Identity::Api.consent_terms(purpose: "health_data")).to eq(Identity::Api::ConsentTerms.new(version: 1, operator: nil, region: nil))
  end

  it "answers nil for an unknown purpose" do
    expect(Identity::Api.consent_terms(purpose: "nope")).to be_nil
  end
end
