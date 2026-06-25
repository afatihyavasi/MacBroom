cask "macbroom" do
  version "1.0.1"
  sha256 "e9e5c616b82b01700b6a151ae0642c58ccbba708effebab327890653b6372355"

  url "https://github.com/afatihyavasi/MacBroom/releases/download/v#{version}/MacBroom-#{version}.dmg"
  name "MacBroom"
  desc "Safe, open-source AI and system cache cleaner for the menu bar"
  homepage "https://github.com/afatihyavasi/MacBroom"

  depends_on macos: :ventura

  app "MacBroom.app"

  # 1.0.0 is unsigned (no Apple Developer ID yet), so it installs quarantined.
  # On first launch: right-click MacBroom → Open, or clear it once with
  # `xattr -dr com.apple.quarantine /Applications/MacBroom.app`.
  # Notarized releases will open with no prompt.

  zap trash: [
    "~/Library/LaunchAgents/com.macbroom.autoclean.*",
    "~/Library/Preferences/com.macbroom.app.plist",
  ]
end
