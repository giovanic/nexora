# Applied wherever Rails reports parameters. Sensitive data never enters logs,
# metrics or error reports (docs/engineering/OBSERVABILITY.md).
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :code, :state, :authorization, :cookie, :session, :key, :url, :upload_url, :upload_headers,
  :name, :phone, :birth, :ip, :label,
  :photo, :image, :food, :term, :meal, :item, :nutrition, :calorie, :kcal, :portion, :grams, :carbs, :protein, :fat, :fiber, :sodium,
  :weight, :sport, :sleep, :water, :goal, :activity, :strava, :athlete, :raw_response, :prompt,
  :photo_key, :object_key, :upload_url, :"X-Amz-Signature", :"X-Amz-Credential", :"X-Amz-Security-Token"
]
