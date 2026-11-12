require "rails_helper"

RSpec.describe Identity::User do
  def build_user(**attributes)
    described_class.new(email: "ana@example.test", password: "correct horse battery", adult_confirmed_at: Time.current, **attributes)
  end

  it "database rejects a user without adult_confirmed_at" do
    expect {
      described_class.insert_all!([ { email: "ana@example.test", password_digest: "x", adult_confirmed_at: nil } ])
    }.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "requires the adult confirmation" do
    user = build_user(adult_confirmed_at: nil)

    expect(user).not_to be_valid
    expect(user.errors.details[:adult_confirmed_at]).to include(error: :blank)
  end

  it "treats \" Ana@X.com \" as ana@x.com" do
    build_user(email: " Ana@X.com ").save!

    expect(described_class.find_by(email: "ana@x.com")).to be_present
    expect(described_class.find_by(email: " ANA@x.COM")).to be_present
  end

  it "email is encrypted at rest: the raw SQL does not contain the e-mail" do
    user = build_user(email: "ana@example.test")
    user.save!

    raw = described_class.connection.select_value("SELECT email FROM users WHERE id = #{described_class.connection.quote(user.id)}")

    expect(raw).not_to include("ana@example.test")
    expect(raw).not_to include("ana")
  end

  it "refuses a second account with the same e-mail, in the database too" do
    build_user(email: "ana@example.test").save!

    expect(build_user(email: "ANA@example.test")).not_to be_valid
    expect { build_user(email: "ana@example.test").save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "refuses an e-mail without a valid format" do
    expect(build_user(email: "ana")).not_to be_valid
  end

  it "refuses an e-mail longer than 254 characters, as the contract says" do
    address = ->(last_label) { "#{'a' * 64}@#{'b' * 60}.#{'c' * 60}.#{'d' * last_label}.test" }

    expect(address.call(62).length).to eq(254)
    expect(build_user(email: address.call(62))).to be_valid
    expect(build_user(email: address.call(63))).not_to be_valid
  end

  describe "password between 12 characters and 72 bytes" do
    it "refuses 11 characters" do
      expect(build_user(password: "a" * 11)).not_to be_valid
    end

    it "accepts 12 characters" do
      expect(build_user(password: "a" * 12)).to be_valid
    end

    it "accepts 72 bytes" do
      expect(build_user(password: "a" * 72)).to be_valid
    end

    it "refuses 73 bytes, even with fewer characters" do
      password = "ç" * 36 + "a" # 36 characters of 2 bytes, plus 1

      expect(password.bytesize).to eq(73)
      expect(build_user(password:)).not_to be_valid
    end
  end

  it "stores only the bcrypt digest of the password" do
    user = build_user(password: "correct horse battery")
    user.save!

    expect(user.password_digest).to start_with("$2")
    expect(user.reload.password_digest).not_to include("correct horse battery")
  end
end
