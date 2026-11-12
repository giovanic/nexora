module Identity
  class User < ApplicationRecord
    self.table_name = "users"

    MIN_PASSWORD_LENGTH = 12
    MAX_EMAIL_LENGTH = 254

    PASSWORD_RESET_EXPIRES_IN = 15.minutes

    # The reset token embeds the end of the password salt, so changing the
    # password ends every token issued before (design 4.1).
    has_secure_password reset_token: { expires_in: PASSWORD_RESET_EXPIRES_IN }
    # URL-safe, so the token travels in the link fragment and in the request
    # path without escaping. Its own key, apart from other signed messages.
    self.generated_token_verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("identity/user token_for"), digest: "SHA256", serializer: JSON, url_safe: true
    )
    has_many :sessions, class_name: "Identity::Session"

    # Normalized before encryption, so the same address always gives the same
    # ciphertext and the unique index holds (design 4.2).
    normalizes :email, with: ->(email) { email.strip.downcase }
    encrypts :email, deterministic: true

    validates :email, presence: true, length: { maximum: MAX_EMAIL_LENGTH }, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true
    validates :adult_confirmed_at, presence: true
    # has_secure_password already refuses more than 72 bytes, the bcrypt limit.
    validates :password, length: { minimum: MIN_PASSWORD_LENGTH }, allow_nil: true

    scope :active, -> { where(deleted_at: nil) }
  end
end
