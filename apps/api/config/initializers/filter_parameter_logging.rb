# Applied wherever Rails reports parameters. Sensitive data never enters logs,
# metrics or error reports (docs/engineering/OBSERVABILITY.md).
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :photo, :signed_url, :food, :meal, :item, :nutrition, :calorie, :activity
]
