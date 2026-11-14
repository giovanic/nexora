module FoodAi
  # Registry of the prompt versions in use. The files are immutable (see PromptCatalog).
  class PromptVersion < ApplicationRecord
    self.table_name = "prompt_versions"

    validates :version, :schema_version, :body_ref, presence: true
    validates :version, uniqueness: true
  end
end
