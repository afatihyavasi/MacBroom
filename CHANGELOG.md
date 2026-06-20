# Changelog

Bu proje [Semantic Versioning](https://semver.org/) ve [Keep a Changelog](https://keepachangelog.com/) kurallarını izler.

## [Unreleased]

### Added
- Proje iskeleti: PRD, README, GPL-3.0 lisansı, katkı rehberi.
- `vendor/mole` submodule (pinned V1.43.1).
- `macbroom-engine.sh`: mole `lib/`'ini source eden JSON köprüsü
  (`scan/clean/ai-scan/ai-clean/apps/app-scan/app-clean/status/version`).
- SwiftUI `MenuBarExtra` uygulaması (`MacBroomCore` + `MacBroom`).
- AI cache temizliği: Codex/Claude/Gemini/Cursor araç-bazlı, state korunur.
- Sistem cache temizliği (opt-in seçim).
- Canlı disk + bellek durumu paneli.
- App uninstaller (uygulama + kalıntılar, onaylı silme).
- Ayarlar: silme yöntemi (kalıcı / Çöp Kutusu), Tam Disk Erişimi yönlendirmesi,
  mole atfı; ilk açılış FDA banner'ı.
