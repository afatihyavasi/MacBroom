cask "macbroom" do
  version "1.0.1"
  sha256 "e9e5c616b82b01700b6a151ae0642c58ccbba708effebab327890653b6372355"

  url "https://github.com/afatihyavasi/MacBroom/releases/download/v#{version}/MacBroom-#{version}.dmg"
  name "MacBroom"
  desc "Safe, open-source AI and system cache cleaner for the menu bar"
  homepage "https://github.com/afatihyavasi/MacBroom"

  depends_on macos: :ventura

  app "MacBroom.app"

  # Releases are not notarized yet (no Apple Developer ID), and Gatekeeper
  # reports quarantined ad-hoc-signed apps as "damaged" on Apple Silicon —
  # right-click → Open does not bypass that dialog. Personal taps may strip
  # the quarantine flag at install time so the app opens normally.
  # Remove this block once releases are signed + notarized.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/MacBroom.app"],
                   sudo:         false,
                   must_succeed: false
  end

  zap trash: [
    "~/Library/LaunchAgents/com.macbroom.autoclean.*",
    "~/Library/Preferences/com.macbroom.app.plist",
  ]
end
