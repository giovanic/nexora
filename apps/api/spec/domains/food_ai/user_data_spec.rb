require "rails_helper"

RSpec.describe FoodAi::UserData do
  let(:user) { Identity::User.create!(email: "ud-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current) }
  let(:other) { Identity::User.create!(email: "ud-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current) }

  def seed_for(person)
    photo = FoodAi::FoodPhoto.create!(user_id: person.id, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}",
                                      content_type: "image/jpeg", byte_size: 3, status: "stored", authorized_at: Time.current)
    FoodAi.storage.write(key: photo.object_key, bytes: "abc", content_type: "image/jpeg")
    analysis = FoodAi::AnalysisResult.create!(user_id: person.id, photo_id: photo.id, provider: "fake", model: "fake-1", prompt_version: "food_vision_v1",
                                              schema_version: "1", status: "succeeded", raw_response: { "contains_food" => true }, started_at: Time.current)
    usage = FoodAi::UsageRecord.create!(analysis_id: analysis.id, user_id: person.id, provider: "fake", model: "fake-1", input_tokens: 1,
                                        output_tokens: 1, cost_usd: BigDecimal("0.00000100"), occurred_at: Time.current)
    [ photo, analysis, usage ]
  end

  it "exports only the person's rows" do
    seed_for(user)
    seed_for(other)

    data = described_class.export(user.id)

    expect(data[:photos].size).to eq(1)
    expect(data[:photos].first).not_to have_key(:object_key)
    expect(data[:analyses].first).not_to have_key(:raw_response)
    expect(data[:analyses].first[:status]).to eq("succeeded")
    expect(data[:usage].first[:cost_usd]).to eq("0.000001")
  end

  it "erases photos, objects and analyses, keeps cost unlinked, and leaves others alone" do
    photo, = seed_for(user)
    other_photo, = seed_for(other)

    2.times { described_class.erase(user.id) }

    expect(FoodAi::FoodPhoto.where(user_id: user.id)).to be_empty
    expect(FoodAi::AnalysisResult.where(user_id: user.id)).to be_empty
    expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
    expect(FoodAi::UsageRecord.where(user_id: nil, analysis_id: nil).count).to eq(1)
    expect(FoodAi::FoodPhoto.where(id: other_photo.id)).to exist
    expect(FoodAi::UsageRecord.where(user_id: other.id)).to exist
  end

  it "does not put provider or model values in the database schema" do
    checks = ActiveRecord::Base.connection.check_constraints("ai_usage_records").map(&:name)
    expect(checks).to eq([ "ai_usage_records_non_negative" ])
  end

  it "validates provider and model as plain identifiers in code" do
    row = FoodAi::UsageRecord.new(provider: "free text!", model: "x" * 65, input_tokens: 0, output_tokens: 0, cost_usd: 0, occurred_at: Time.current)
    expect(row).not_to be_valid
    expect(row.errors.attribute_names).to include(:provider, :model)
  end

  it "allows every priced model in usage records" do
    FoodAi::Pricing::TABLE.each_key do |provider, model|
      expect do
        FoodAi::UsageRecord.create!(user_id: user.id, provider: provider, model: model, input_tokens: 0, output_tokens: 0, cost_usd: 0, occurred_at: Time.current)
      end.not_to raise_error
    end
  end
end
