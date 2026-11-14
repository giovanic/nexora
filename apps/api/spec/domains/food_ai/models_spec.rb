require "rails_helper"

RSpec.describe "FoodAi tables" do
  let(:user) do
    Identity::User.create!(email: "ai-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current)
  end

  def photo(attrs = {})
    FoodAi::FoodPhoto.create!({ user_id: user.id, client_request_id: SecureRandom.uuid, object_key: "food-photos/#{SecureRandom.uuid}",
                                content_type: "image/jpeg", byte_size: 1000, status: "awaiting_upload", authorized_at: Time.current }.merge(attrs))
  end

  def result(photo, attrs = {})
    FoodAi::AnalysisResult.create!({ user_id: user.id, photo_id: photo.id, provider: "fake", model: "fake-1", prompt_version: "food_vision_v1",
                                     schema_version: "1", status: "running", started_at: Time.current }.merge(attrs))
  end

  describe FoodAi::FoodPhoto do
    it "validates status and the unique keys" do
      expect(described_class.new(status: "nope")).not_to be_valid
      first = photo
      expect { photo(object_key: first.object_key) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { photo(client_request_id: first.client_request_id) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "enforces uniqueness and status in the database too" do
      first = photo
      dup = described_class.new(first.attributes.except("id"))
      expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      bad = described_class.new(first.attributes.except("id").merge("object_key" => "food-photos/x", "client_request_id" => "y", "status" => "weird"))
      expect { bad.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /food_photos_status_known/)
    end
  end

  describe FoodAi::AnalysisResult do
    it "allows one non-failed run per photo and prompt version" do
      pic = photo
      result(pic, status: "succeeded")
      expect { result(pic, status: "running") }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "lets a retry run after a failed or cancelled one" do
      pic = photo
      result(pic, status: "failed", error_code: "timeout")
      result(pic, status: "cancelled")
      expect { result(pic, status: "running") }.not_to raise_error
      expect { result(pic, status: "succeeded") }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "keeps status and error_code to closed lists" do
      pic = photo
      expect(described_class.new(status: "weird")).not_to be_valid
      expect(described_class.new(status: "failed", error_code: "raw model text")).not_to be_valid
      bad = described_class.new(user_id: user.id, photo_id: pic.id, provider: "p", model: "m", prompt_version: "v", schema_version: "1",
                                status: "failed", error_code: "free text", started_at: Time.current)
      expect { bad.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /food_analysis_results_error_code_known/)
    end

    it "accepts every code a provider error can carry" do
      codes = [ FoodAi::TransientProviderError, FoodAi::PermanentProviderError, FoodAi::InvalidOutputError ].flat_map { |k| k::CODES }
      expect(described_class::ERROR_CODES).to include(*codes)
    end

    it "has a plain index on photo_id, which the cascade from food_photos needs" do
      indexes = ActiveRecord::Base.connection.indexes("food_analysis_results")
      expect(indexes.any? { |i| i.columns == [ "photo_id" ] && i.where.nil? && !i.unique }).to be(true)
    end

    it "stores raw_response as validated JSON" do
      row = result(photo, status: "succeeded", raw_response: { "contains_food" => false })
      expect(row.reload.raw_response).to eq({ "contains_food" => false })
    end
  end

  describe FoodAi::UsageRecord do
    it "survives the analysis, unlinked, and keeps fractions of a cent" do
      analysis = result(photo)
      usage = described_class.create!(analysis_id: analysis.id, user_id: user.id, provider: "fake", model: "fake-1",
                                      input_tokens: 10, output_tokens: 5, cost_usd: BigDecimal("0.00001234"), occurred_at: Time.current)

      analysis.destroy!

      usage.reload
      expect(usage.analysis_id).to be_nil
      expect(usage.cost_usd).to eq(BigDecimal("0.00001234"))
    end

    it "accepts a record without user (after the 90-day unlink)" do
      usage = described_class.create!(user_id: nil, provider: "fake", model: "fake-1", input_tokens: 1, output_tokens: 1,
                                      cost_usd: 0, occurred_at: Time.current)
      expect(usage).to be_persisted
    end
  end

  describe FoodAi::PromptVersion do
    it "has a unique version" do
      described_class.create!(version: "v_test", schema_version: "1", body_ref: "x", activated_at: Time.current)
      expect(described_class.new(version: "v_test", schema_version: "1", body_ref: "x")).not_to be_valid
    end
  end
end
