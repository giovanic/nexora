module Identity
  # The purposes of consent, the version of each text in force, and the texts
  # themselves, versioned in config/consents/<purpose>.v<N>.md (design 4.5).
  # A new version is a new file and a change here; old files stay, since
  # records point to the version the person accepted.
  module ConsentTexts
    CURRENT_VERSIONS = {
      "health_data" => 1,
      "food_photo_ai" => 1,
      "strava_integration" => 1,
      "usage_metrics" => 1
    }.freeze
    PURPOSES = CURRENT_VERSIONS.keys.freeze
    DIRECTORY = Rails.root.join("config/consents")

    def self.purpose?(purpose)
      PURPOSES.include?(purpose)
    end

    def self.current_version(purpose)
      CURRENT_VERSIONS.fetch(purpose) { raise ArgumentError, "unknown consent purpose" }
    end

    # Only purposes from the closed list reach the file name.
    def self.read(purpose)
      DIRECTORY.join("#{purpose}.v#{current_version(purpose)}.md").read
    end
  end
end
