class ApplicationController < ActionController::API
  include ErrorRendering
  include Authentication

  # Bodies are read flat, as the contract describes them.
  wrap_parameters false
end
