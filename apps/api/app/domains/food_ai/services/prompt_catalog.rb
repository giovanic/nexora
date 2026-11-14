require "digest"
require "json"
require "yaml"

module FoodAi
  # Versioned prompts live in config/prompts/<version>.md and <version>.schema.json. A version
  # is immutable once registered: config/prompts/digests.yml holds the sha256 of both files,
  # and loading a prompt whose file differs raises. A change means a new version.
  class PromptCatalog
    CURRENT_VERSION = "food_vision_v1".freeze
    DIR = Rails.root.join("config/prompts")

    class TamperedError < StandardError; end

    def self.current = self.load(CURRENT_VERSION)

    def self.load(version)
      entry = YAML.load_file(DIR.join("digests.yml")).fetch(version) { raise TamperedError, "version not registered" }
      body = File.read(DIR.join("#{version}.md"))
      schema_json = File.read(DIR.join("#{version}.schema.json"))
      unless Digest::SHA256.hexdigest(body) == entry["body"] && Digest::SHA256.hexdigest(schema_json) == entry["schema"]
        raise TamperedError, "prompt files differ from the registered digest"
      end

      Prompt.new(version: version, schema_version: entry.fetch("schema_version").to_s, body: body.freeze, schema: JSON.parse(schema_json))
    end

    # Records the version in prompt_versions, once.
    def self.register!(prompt)
      PromptVersion.find_or_create_by!(version: prompt.version) do |row|
        row.schema_version = prompt.schema_version
        row.body_ref = "config/prompts/#{prompt.version}.md"
        row.activated_at = Time.current
      end
    rescue ActiveRecord::RecordNotUnique
      PromptVersion.find_by!(version: prompt.version)
    end
  end
end
