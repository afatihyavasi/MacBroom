cask "macbroom" do
  version "2.0.0"

  # Her sürümde güncelleyin:  shasum -a 256 MacBroom-<version>.dmg
  # İmzasız/notarize edilmemiş yerel test DMG'leri için ":no_check" kullanın.
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  # <OWNER> yerine GitHub kullanıcı/organizasyon adınızı yazın.
  url "https://github.com/<OWNER>/macbroom/releases/download/v#{version}/MacBroom-#{version}.dmg",
      verified: "github.com/<OWNER>/macbroom/"
  name "MacBroom"
  desc "Safe, open-source AI & system cache cleaner for the macOS menu bar"
  homepage "https://github.com/<OWNER>/macbroom"

  depends_on macos: ">= :ventura"

  app "MacBroom.app"

  zap trash: [
    "~/Library/LaunchAgents/com.macbroom.autoclean.*",
    "~/Library/Preferences/com.macbroom.app.plist",
  ]
end
