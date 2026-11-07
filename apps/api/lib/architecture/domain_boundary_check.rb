require "prism"
require "active_support/core_ext/string/inflections"

module Architecture
  # Enforces docs/architecture/DOMAIN_MODEL.md statically: a context reaches
  # another only through <Context>::Api, and only if its rules allow it.
  # It cannot see references built at runtime or direct SQL (see ADR 0003).
  class DomainBoundaryCheck
    Violation = Data.define(:file, :line, :from, :to, :constant, :reason)

    class UnparseableFile < StandardError; end
    class UnknownContext < StandardError; end

    SHARED = "shared".freeze
    PUBLIC_API = "Api".freeze
    QUALIFIED_CONSTANT = /\A(?:::)?[A-Z]\w*(?:::[A-Z]\w*)+\z/

    def self.cycles(rules)
      found = []
      visit = lambda do |node, trail|
        if trail.include?(node)
          found << trail.drop_while { |step| step != node } + [ node ]
        else
          rules.fetch(node, []).each { |target| visit.call(target, trail + [ node ]) }
        end
      end
      rules.each_key { |node| visit.call(node, []) }
      found
    end

    def initialize(root:, rules:)
      @root = root.to_s
      @rules = rules
      @context_by_constant = (rules.keys + [ SHARED ]).to_h { |context| [ context.camelize, context ] }
    end

    def violations
      Dir.glob(File.join(@root, "**", "*.rb")).sort.flat_map { |file| check_file(file) }
    end

    private

    def check_file(file)
      from = context_of(file)
      result = Prism.parse_file(file)
      raise UnparseableFile, "#{file}: #{result.errors.first&.message}" unless result.success?

      collector = ReferenceCollector.new
      result.value.accept(collector)
      collector.references.filter_map { |name, line| judge(file, from, name, line) }
    end

    def context_of(file)
      context = file.delete_prefix("#{@root}/").split("/").first
      return context if context == SHARED || @rules.key?(context)

      raise UnknownContext, "#{context} has no rules in config/domain_boundaries.yml"
    end

    def judge(file, from, name, line)
      parts = name.delete_prefix("::").split("::")
      to = @context_by_constant[parts.first]
      return if to.nil? || to == from || to == SHARED

      reason = reason_for(from, to, parts)
      Violation.new(file:, line:, from:, to:, constant: parts.join("::"), reason:) if reason
    end

    def reason_for(from, to, parts)
      return :forbidden_dependency unless @rules.fetch(from, []).include?(to)

      :private_constant unless parts.size == 2 && parts.last == PUBLIC_API
    end

    class ReferenceCollector < Prism::Visitor
      attr_reader :references

      def initialize
        super
        @references = []
      end

      # The outermost path is the whole reference, so its inner parts are skipped.
      def visit_constant_path_node(node)
        @references << [ node.full_name, node.location.start_line ]
      rescue Prism::ConstantPathNode::DynamicPartsInConstantPathError
        super
      end

      def visit_constant_read_node(node)
        @references << [ node.name.to_s, node.location.start_line ]
      end

      def visit_string_node(node)
        @references << [ node.unescaped, node.location.start_line ] if node.unescaped.match?(QUALIFIED_CONSTANT)
      end
    end
    private_constant :ReferenceCollector
  end
end
