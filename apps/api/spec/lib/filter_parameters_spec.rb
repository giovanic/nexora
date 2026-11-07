require "rails_helper"

RSpec.describe "filtered parameters" do
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  %w[password email access_token client_secret photo_url signed_url food_items meal_name nutrition_data calories activity_name].each do |name|
    it "filters #{name}" do
      expect(filter.filter(name => "value")[name]).to eq("[FILTERED]")
    end
  end

  it "keeps a neutral parameter" do
    expect(filter.filter("page" => "2")["page"]).to eq("2")
  end
end
