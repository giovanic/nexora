require "marcel"
require "yaml"
require_relative "metrics"

module Evaluation
  # Runs the real pipeline pieces on the dataset, one photo and one provider at a time, without writing a meal,
  # a photo or an analysis to the database: FoodAi::NormalizePhoto, the adapter, FoodAi::ValidateOutput,
  # FoodCatalog::Api.match and Nutrition::Api.estimate. Loaded inside Rails (bin/rails runner), never standalone.
  #
  # What the run keeps of an answer: codes, counts, grams, latency, tokens and cost. Never the text the model
  # wrote, the image, or a signed URL: the report is built from these records only.
  class Runner
    TRANSIENT_ATTEMPTS = 3
    TRANSIENT_WAIT = 5 # seconds, times the attempt number

    def initialize(manifest:, annotations:, dir:, sleeper: Kernel.method(:sleep), clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @images = manifest.fetch("images")
      @annotations = annotations.fetch("annotations")
      @dir = dir
      @sleeper = sleeper
      @clock = clock
      @keys = {}
    end

    attr_reader :images

    # The key two names share when they mean the same food for the pipeline: the catalog item they match, or
    # (for a name the catalog does not know) the plain name without accents or case.
    def key_for(name)
      @keys[name] ||= begin
        found = FoodCatalog::Api.match(name:)
        found ? "catalog:#{found.catalog_item_id}" : "text:#{plain(name)}"
      end
    end

    def plain(name) = name.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip

    # One record for one photo and one provider adapter (see Metrics.summarize for the fields).
    def evaluate(entry, adapter:)
      annotation = @annotations.fetch(entry["id"])
      expected_items = (annotation["items"] || []).map { |item| { key: key_for(item["name"]), grams: item["grams"] }.compact }
      record = { image: entry["id"], expect: annotation.fetch("expect"), status: "failed", latency: nil, cost: nil, input_tokens: 0, output_tokens: 0,
                 error: nil, valid: false, texts: [], expected_keys: expected_items.map { _1[:key] }, expected_items:, predicted_keys: [],
                 predicted_items: [], matched_items: 0, unknown_items: 0, estimate_partial: nil, attempts: 0 }

      photo = normalize(entry)
      return record.merge(error: "invalid_photo") unless photo

      response, latency, attempts, error = call_provider(adapter, photo)
      record[:attempts] = attempts
      return record.merge(error:) unless response

      record.merge!(latency:, cost: response.cost_usd, input_tokens: response.input_tokens, output_tokens: response.output_tokens)
      begin
        output = FoodAi::ValidateOutput.call(response.payload)
      rescue FoodAi::InvalidOutputError => e
        return record.merge(error: e.code)
      end
      describe_output(record, output)
    end

    private

    def normalize(entry)
      bytes = File.binread(File.join(@dir, entry.fetch("file")))
      FoodAi::NormalizePhoto.call(bytes:, declared_type: Marcel::MimeType.for(StringIO.new(bytes)).to_s)
    rescue FoodAi::InvalidPhotoError, Errno::ENOENT
      nil
    end

    # Transient errors (timeout, 429, 5xx) are retried like the job does; an invalid answer is not, so the rate
    # of invalid or truncated answers shows. Returns response, latency of the call that worked, attempts, error code.
    def call_provider(adapter, photo)
      prompt = FoodAi::PromptCatalog.current
      attempts = 0
      begin
        attempts += 1
        started = @clock.call
        response = adapter.analyze(image: photo.bytes, content_type: photo.content_type, prompt:, schema: prompt.schema)
        [ response, @clock.call - started, attempts, nil ]
      rescue FoodAi::TransientProviderError => e
        if attempts < TRANSIENT_ATTEMPTS
          @sleeper.call(TRANSIENT_WAIT * attempts)
          retry
        end
        [ nil, nil, attempts, e.code ]
      rescue FoodAi::ProviderError => e
        [ nil, nil, attempts, e.code ]
      end
    end

    def describe_output(record, output)
      status = if output.image_quality == "unreadable" then "unreadable"
      elsif !output.contains_food then "no_food"
      elsif output.items.empty? then "unreadable"
      else "succeeded"
      end
      matches = output.items.map { |item| [ item, FoodCatalog::Api.match(name: item.name) ] }
      estimate = Nutrition::Api.estimate(items: matches.map do |item, found|
        { catalog_item_id: found&.catalog_item_id, grams_min: item.portion.grams_min, grams_likely: item.portion.grams_likely, grams_max: item.portion.grams_max }
      end)
      record.merge(
        status:, valid: true, texts: output.items.flat_map { [ _1.name, _1.preparation, _1.portion.household_measure ] },
        predicted_keys: matches.map { |item, found| found ? "catalog:#{found.catalog_item_id}" : "text:#{plain(item.name)}" },
        predicted_items: matches.map do |item, found|
          { key: found ? "catalog:#{found.catalog_item_id}" : "text:#{plain(item.name)}",
            grams_min: item.portion.grams_min, grams_likely: item.portion.grams_likely, grams_max: item.portion.grams_max }
        end,
        matched_items: matches.count { _2 }, unknown_items: matches.count { !_2 }, estimate_partial: estimate.estimate_partial
      )
    end
  end
end
