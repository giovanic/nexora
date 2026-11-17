# In production the app does not boot when a provider is configured and its operator or region
# do not match the food_photo_ai text in force: people would be asked to consent to one company
# while photos went to another. Without FOOD_AI_PROVIDER it boots, and uploads are refused
# with consent_operator_mismatch.
Rails.application.config.after_initialize do
  FoodAi::Api.verify_operator! if Rails.env.production?
end
