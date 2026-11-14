# Evaluation of the Food AI pipeline on the licensed dataset. Costs money with real providers: never run by the suite.
#
#   cd apps/api && bin/rails runner ../../evaluation/run.rb PROVIDERS=anthropic:<model>,gemini:<model>,openai:<model> [ROUND=r1]
#   cd apps/api && bin/rails runner ../../evaluation/run.rb CATALOG_ONLY=1      (no provider, no network: the match rate only)
#
# Keys come from ANTHROPIC_API_KEY, GEMINI_API_KEY and OPENAI_API_KEY. Without the key of a listed provider the run
# stops before reading any image or calling anything, with status 1. Images come from EVALUATION_IMAGES_DIR (default
# ~/.cache/nexora-evaluation), rebuilt by evaluation/fetch.rb. The report goes to evaluation/reports/AAAA-MM-DD-<round>.md.
require "date"
require "fileutils"
require "yaml"
require_relative "fetch"
require_relative "runner"
require_relative "report"
require_relative "catalog_check"

module Evaluation
  module Run
    ROOT = __dir__
    REPORTS = File.join(ROOT, "reports")
    EXPECTED_ENV = { "anthropic" => "ANTHROPIC_API_KEY", "gemini" => "GEMINI_API_KEY", "openai" => "OPENAI_API_KEY" }.freeze

    module_function

    def parse(argv)
      argv.to_h { |arg| arg.split("=", 2) }.transform_keys(&:upcase)
    end

    # "anthropic:model,gemini:model" => [["anthropic", "model"], ...]
    def providers_from(text)
      text.to_s.split(",").map { |pair| pair.strip.split(":", 2) }.reject { _1.compact.empty? }
    end

    # nil when all is well, else the message (no key value, ever).
    def refusal(pairs, env: ENV)
      return "PROVIDERS vazio. Uso: PROVIDERS=anthropic:<modelo>,gemini:<modelo>,openai:<modelo> (ou CATALOG_ONLY=1 para a etapa sem provedor)." if pairs.empty?

      pairs.each do |provider, model|
        return "Provedor desconhecido: #{provider}. Use anthropic, gemini ou openai." unless EXPECTED_ENV.key?(provider)
        return "Falta o modelo de #{provider}. Formato: #{provider}:<modelo>." if model.to_s.empty?
        return "Falta a variável #{EXPECTED_ENV.fetch(provider)}: nenhuma chamada foi feita." if env[EXPECTED_ENV.fetch(provider)].to_s.strip.empty?
        return "Modelo sem preço registrado em FoodAi::Pricing: #{provider}:#{model}." unless FoodAi::Pricing::TABLE.key?([ provider, model ])
      end
      nil
    end

    def dataset_summary(manifest)
      images = manifest.fetch("images")
      categories = images.group_by { _1["category"] }.transform_values(&:size)
      { version: manifest.fetch("dataset_version"), total: images.size, categories: }
    end

    def main(argv, env: ENV, out: $stdout, err: $stderr)
      options = parse(argv)
      catalog_only = options["CATALOG_ONLY"].to_s == "1"
      pairs = providers_from(options["PROVIDERS"])
      unless catalog_only
        message = refusal(pairs, env:)
        return fail_with(err, message) if message
      end
      return fail_with(err, "O catálogo está vazio. Rode `bin/rails food_catalog:load`.") if FoodCatalog::CatalogItem.none?

      manifest = YAML.safe_load_file(File.join(ROOT, "manifest.yml"))
      annotations = YAML.safe_load_file(File.join(ROOT, "annotations.yml"))
      dir = Fetch.images_dir(env)
      runner = Runner.new(manifest:, annotations:, dir:)
      date = Date.today.iso8601
      round = options["ROUND"].to_s.strip
      round = catalog_only ? "pre-provider" : "r1" if round.empty?
      FileUtils.mkdir_p(REPORTS)
      path = File.join(REPORTS, "#{date}-#{round}.md")
      catalog = CatalogCheck.call(annotations)

      if catalog_only
        File.write(path, Report.render_catalog_only(date:, round:, dataset: dataset_summary(manifest), catalog:))
        out.puts "report: #{path}"
        return 0
      end

      missing = missing_images(manifest, dir)
      return fail_with(err, "Imagens ausentes ou alteradas em #{dir}: #{missing.size}. Rode `ruby evaluation/fetch.rb`.") unless missing.empty?

      results = pairs.to_h do |provider, model|
        adapter = FoodAi.adapter_for(provider:, model:)
        records = runner.images.map do |entry|
          runner.evaluate(entry, adapter:).tap { |record| out.puts "#{provider}:#{model} #{record[:image]} #{record[:status]} #{record[:error]}".strip }
        end
        [ "#{provider}:#{model}", records ]
      end
      File.write(path, Report.render(date:, round:, prompt_version: FoodAi::PromptCatalog.current.version, dataset: dataset_summary(manifest), providers: results, catalog:))
      out.puts "report: #{path}"
      0
    end

    def missing_images(manifest, dir)
      manifest.fetch("images").reject do |entry|
        path = File.join(dir, entry["file"])
        File.file?(path) && Fetch.sha256(File.binread(path)) == entry["sha256"]
      end
    end

    def fail_with(err, message)
      err.puts "evaluation/run.rb: #{message}"
      1
    end
  end
end
