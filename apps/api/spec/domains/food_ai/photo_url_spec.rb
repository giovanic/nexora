require "rails_helper"

RSpec.describe "FoodAi::Api.photo_url" do
  let(:user) { Identity::User.create!(email: "pu-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current) }

  def photo(status: "stored", user_id: user.id)
    FoodAi::FoodPhoto.create!(user_id:, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}", content_type: "image/jpeg",
                              status:, authorized_at: Time.current)
  end

  it "signs a get url of at most 900 seconds for a stored photo" do
    stored = photo
    allow(FoodAi.storage).to receive(:presigned_get).and_call_original

    url = FoodAi::Api.photo_url(user_id: user.id, photo_id: stored.id)

    expect(url).to eq("memory://download/#{stored.object_key}")
    expect(FoodAi.storage).to have_received(:presigned_get).with(key: stored.object_key, expires_in: 900)
  end

  it "is nil for a deleted, awaiting, absent or another person's photo, and for no photo" do
    other = Identity::User.create!(email: "pu2-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current)

    expect(FoodAi::Api.photo_url(user_id: user.id, photo_id: photo(status: "deleted").id)).to be_nil
    expect(FoodAi::Api.photo_url(user_id: user.id, photo_id: photo(status: "awaiting_upload").id)).to be_nil
    expect(FoodAi::Api.photo_url(user_id: user.id, photo_id: SecureRandom.uuid)).to be_nil
    expect(FoodAi::Api.photo_url(user_id: user.id, photo_id: nil)).to be_nil
    expect(FoodAi::Api.photo_url(user_id: other.id, photo_id: photo.id)).to be_nil
  end
end
