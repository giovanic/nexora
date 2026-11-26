namespace :food_ai do
  DEFAULT_SMOKE_MODELS = {
    "anthropic" => "claude-haiku-5-5",
    "gemini" => "gemini-3.5-flash-lite",
    "openai" => "gpt-6-luna",
    "groq" => "qwen/qwen3.8-27b"
  }.freeze

  desc "Real call to one AI provider with one photo. PROVIDER=anthropic|gemini|openai|groq [MODEL=...] IMAGE=path. Needs the provider key; costs money; never run by the suite."
  task smoke: :environment do
    provider = ENV.fetch("PROVIDER", "").to_s
    model = ENV["MODEL"].presence || DEFAULT_SMOKE_MODELS[provider]
    path = ENV["IMAGE"].to_s
    abort "food_ai:smoke: PROVIDER must be anthropic, gemini, openai or groq" unless DEFAULT_SMOKE_MODELS.key?(provider)
    abort "food_ai:smoke: IMAGE must be a readable file" unless File.file?(path)

    begin
      adapter = FoodAi.adapter_for(provider: provider, model: model)
    rescue FoodAi::ProviderError => e
      abort "food_ai:smoke: cannot start (#{e.code}); set the provider key in the environment"
    end

    bytes = File.binread(path)
    declared = Marcel::MimeType.for(StringIO.new(bytes)).to_s
    photo = FoodAi::NormalizePhoto.call(bytes: bytes, declared_type: declared)
    prompt = FoodAi::PromptCatalog.current

    begin
      response = adapter.analyze(image: photo.bytes, content_type: photo.content_type, prompt: prompt, schema: prompt.schema)
      validated = FoodAi::ValidateOutput.call(response.payload)
      puts "status=ok provider=#{response.provider} model=#{response.model} input_tokens=#{response.input_tokens} " \
           "output_tokens=#{response.output_tokens} cost_usd=#{response.cost_usd.to_s('F')} items=#{validated.items.size}"
    rescue FoodAi::ProviderError => e
      abort "food_ai:smoke: status=failed provider=#{provider} model=#{model} code=#{e.code}"
    end
  end
end
