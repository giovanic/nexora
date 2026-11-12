module Observability
  # Rails filters parameters in the query string, but not in path segments.
  # A route can carry a secret in the path, such as the password reset token,
  # so a segment whose parameter name is on the filter list is hidden too.
  module FilteredPath
    FILTERED = "[FILTERED]".freeze

    def self.call(request, path)
      return path unless request && path

      parameters = request.path_parameters
      filtered = parameter_filter.filter(parameters)
      parameters.each do |name, value|
        next unless value.is_a?(String) && !value.empty? && filtered[name] != value

        [ value, ERB::Util.url_encode(value) ].uniq.each { |form| path = path.gsub(form, FILTERED) }
      end
      path
    end

    # The same list Rails applies to parameters (config/initializers/filter_parameter_logging.rb).
    def self.parameter_filter
      @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    end
    private_class_method :parameter_filter
  end
end
