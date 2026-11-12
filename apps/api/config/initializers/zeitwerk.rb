# Inside a context, these folders only organize files: app/domains/nutrition/models/food_entry.rb
# defines Nutrition::FoodEntry, as the domain documents name it. Other folders,
# such as adapters and events, stay in the constant name (ADR 0003).
%w[models services jobs].each do |folder|
  Rails.autoloaders.main.collapse(Rails.root.join("app/domains/*/#{folder}").to_s)
end
