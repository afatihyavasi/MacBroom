cask "macbroom" do
  version "1.0.0"
  sha256 "a0c18780317d3bcf54ef9d0d432c7954b4091638ec4ce130e4fc26527fb72e9d"

  url "https://github.com/afatihyavasi/MacBroom/releases/download/v#{version}/MacBroom-#{version}.dmg"
  name "MacBroom"
  desc "Safe, open-source AI and system cache cleaner for the menu bar"
  homepage "https://github.com/afatihyavasi/MacBroom"

  depends_on macos: :ventura

  app "MacBroom.app"

  # 1.0.0 is unsigned (no Apple Developer ID yet). Install with
  # `brew install --cask --no-quarantine afatihyavasi/tap/macbroom`, or
  # right-click → Open the first time. Notarized releases will open with no prompt.

  zap trash: [
    "~/Library/LaunchAgents/com.macbroom.autoclean.*",
    "~/Library/Preferences/com.macbroom.app.plist",
  ]
end
