cask "macbroom" do
  version "2.0.0"

  # Update on every release:  shasum -a 256 MacBroom-<version>.dmg
  # Use ":no_check" for unsigned/un-notarized local test DMGs.
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  # Replace afatihyavasi with your GitHub user/organization name.
  url "https://github.com/afatihyavasi/MacBroom/releases/download/v#{version}/MacBroom-#{version}.dmg",
      verified: "github.com/afatihyavasi/MacBroom/"
  name "MacBroom"
  desc "Safe, open-source AI & system cache cleaner for the macOS menu bar"
  homepage "https://github.com/afatihyavasi/MacBroom"

  depends_on macos: ">= :ventura"

  app "MacBroom.app"

  zap trash: [
    "~/Library/LaunchAgents/com.macbroom.autoclean.*",
    "~/Library/Preferences/com.macbroom.app.plist",
  ]
end
