# Evaluation of the Food AI pipeline on the licensed dataset. Costs money with real providers: never run by the suite.
#
#   cd apps/api && bin/rails runner ../../evaluation/run.rb PROVIDERS=anthropic:<model>,gemini:<model>,openai:<model>,groq:<model> [ROUND=r1] [PACE=30]
#   cd apps/api && bin/rails runner ../../evaluation/run.rb CATALOG_ONLY=1      (no provider, no network: the match rate only)
#
# PACE: whole seconds (0 to 120) to wait between photos, for a plan with a low rate limit (Groq's free plan).
# Keys come from ANTHROPIC_API_KEY, GEMINI_API_KEY, OPENAI_API_KEY and GROQ_API_KEY. Without the key of a listed provider the run
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
    EXPECTED_ENV = { "anthropic" => "ANTHROPIC_API_KEY", "gemini" => "GEMINI_API_KEY", "openai" => "OPENAI_API_KEY", "groq" => "GROQ_API_KEY" }.freeze
    MAX_PACE = 120

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
      return "PROVIDERS vazio. Uso: PROVIDERS=anthropic:<modelo>,gemini:<modelo>,openai:<modelo>,groq:<modelo> (ou CATALOG_ONLY=1 para a etapa sem provedor)." if pairs.empty?

      pairs.each do |provider, model|
        return "Provedor desconhecido: #{provider}. Use anthropic, gemini, openai ou groq." unless EXPECTED_ENV.key?(provider)
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

    # Seconds to wait between photos: 0 without PACE, nil when PACE is not a whole number from 0 to MAX_PACE.
    def pace_from(text)
      return 0 if text.nil?

      seconds = Integer(text, 10, exception: false)
      seconds if seconds && seconds.between?(0, MAX_PACE)
    end

    def main(argv, env: ENV, out: $stdout, err: $stderr, root: ROOT, sleeper: Kernel.method(:sleep))
      options = parse(argv)
      catalog_only = options["CATALOG_ONLY"].to_s == "1"
      pairs = providers_from(options["PROVIDERS"])
      pace = pace_from(options["PACE"])
      unless catalog_only
        message = refusal(pairs, env:)
        return fail_with(err, message) if message
        return fail_with(err, "PACE deve ser um número inteiro de segundos, de 0 a #{MAX_PACE}.") unless pace
      end
      return fail_with(err, "O catálogo está vazio. Rode `bin/rails food_catalog:load`.") if !FoodCatalog::Api.loaded?

      manifest = YAML.safe_load_file(File.join(root, "manifest.yml"))
      annotations = YAML.safe_load_file(File.join(root, "annotations.yml"))
      dir = Fetch.images_dir(env)
      runner = Runner.new(manifest:, annotations:, dir:)
      date = Date.today.iso8601
      round = options["ROUND"].to_s.strip
      round = catalog_only ? "pre-provider" : "r1" if round.empty?
      reports = File.join(root, "reports")
      path = File.join(reports, "#{date}-#{round}.md")
      catalog = CatalogCheck.call(annotations)

      if catalog_only
        FileUtils.mkdir_p(reports)
        File.write(path, Report.render_catalog_only(date:, round:, dataset: dataset_summary(manifest), catalog:))
        out.puts "report: #{path}"
        return 0
      end

      missing = missing_images(manifest, dir)
      return fail_with(err, "Imagens ausentes ou alteradas em #{dir}: #{missing.size}. Rode `ruby evaluation/fetch.rb`.") unless missing.empty?

      results = {}
      pairs.each do |provider, model|
        label = "#{provider}:#{model}"
        begin
          adapter = FoodAi.adapter_for(provider:, model:)
        rescue FoodAi::PermanentProviderError => error
          return abort_round(err, label, error.code)
        end
        results[label] = runner.images.each_with_index.map do |entry, index|
          sleeper.call(pace) if pace.positive? && index.positive?
          record = runner.evaluate(entry, adapter:)
          out.puts "#{label} #{record[:image]} #{record[:status]} #{record[:error]}".strip
          return abort_round(err, label, record[:error]) if record[:error] == "unauthorized"

          record
        end
      end
      FileUtils.mkdir_p(reports)
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

    # A key the provider refuses would fail every photo and cost nothing but time: stop at the first.
    def abort_round(err, label, code)
      fail_with(err, "#{label} recusou a chamada (#{code}): chave inválida ou sem acesso ao modelo. Rodada abortada, nenhum relatório gravado.")
    end

    def fail_with(err, message)
      err.puts "evaluation/run.rb: #{message}"
      1
    end
  end
end
