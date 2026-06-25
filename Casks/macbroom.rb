cask "macbroom" do
  version "1.0.0"

  # Update on every release:  shasum -a 256 MacBroom-<version>.dmg
  # (The real value is set in the homebrew-tap copy after the release DMG is
  # built; this in-repo file is the template.)
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  # Replace afatihyavasi with your GitHub user/organization name.
  url "https://github.com/afatihyavasi/MacBroom/releases/download/v#{version}/MacBroom-#{version}.dmg",
      verified: "github.com/afatihyavasi/MacBroom/"
  name "MacBroom"
  desc "Safe, open-source AI & system cache cleaner for the macOS menu bar"
  homepage "https://github.com/afatihyavasi/MacBroom"

  depends_on macos: ">= :ventura"

  app "MacBroom.app"
  # 1.0.0 is unsigned (no Apple Developer ID yet), so skip the Gatekeeper
  # quarantine prompt on install. Remove once releases are notarized.
  no_quarantine true

  zap trash: [
    "~/Library/LaunchAgents/com.macbroom.autoclean.*",
    "~/Library/Preferences/com.macbroom.app.plist",
  ]
end
