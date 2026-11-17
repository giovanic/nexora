module FoodAi
  module Adapters
    # Weakens the output JSON Schema to the subset a provider accepts. The backend validates
    # the full schema afterwards (ValidateOutput), so dropping a keyword here loses no check.
    module SchemaTransform
      VALUE_KEYWORDS = %w[minimum maximum exclusiveMinimum exclusiveMaximum multipleOf minLength maxLength].freeze

      # Anthropic structured outputs: no numeric or string constraints, no maxItems,
      # minItems only 0 or 1.
      def self.for_anthropic(schema)
        walk(schema) do |node|
          node = node.reject { |key, _| VALUE_KEYWORDS.include?(key) || key == "maxItems" }
          node.delete("minItems") unless [ 0, 1 ].include?(node["minItems"])
          node
        end
      end

      # OpenAI strict mode: every property required, additionalProperties false, and no
      # validation keywords (they are enforced by the backend instead).
      def self.for_openai(schema)
        walk(schema) do |node|
          node = node.reject { |key, _| VALUE_KEYWORDS.include?(key) || %w[minItems maxItems].include?(key) }
          if node["properties"].is_a?(Hash)
            node["required"] = node["properties"].keys
            node["additionalProperties"] = false
          end
          node
        end
      end

      # Applies the block to every schema node, children first. "properties" maps names
      # to schemas, so its keys are names and never keywords.
      def self.walk(node, &block)
        case node
        when Hash
          mapped = node.to_h do |key, value|
            [ key, key == "properties" && value.is_a?(Hash) ? value.transform_values { |child| walk(child, &block) } : walk(value, &block) ]
          end
          yield mapped
        when Array then node.map { |child| walk(child, &block) }
        else node
        end
      end
      private_class_method :walk
    end
  end
end
