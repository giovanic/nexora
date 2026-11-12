module Identity
  class User < ApplicationRecord
    self.table_name = "users"

    MIN_PASSWORD_LENGTH = 12
    MAX_EMAIL_LENGTH = 254

    has_secure_password
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
