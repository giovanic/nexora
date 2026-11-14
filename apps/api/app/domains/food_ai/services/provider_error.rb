module FoodAi
  # Base of the classified provider errors. Like InvalidPhotoError, it carries only a code
  # from a closed list, and the message is that code: nothing the model returned (text,
  # item names, grams) or the image can reach a log or an error tracker.
  class ProviderError < StandardError
    CODES = [].freeze

    attr_reader :code

    def initialize(code)
      raise ArgumentError, "unknown code" unless self.class::CODES.include?(code.to_s)

      @code = code.to_s
      super(@code)
    end
  end
end
