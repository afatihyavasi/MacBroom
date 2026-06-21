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

### Added (v2)
- shadcn esinli SwiftUI tasarım sistemi (token'lar + yeniden kullanılabilir
  bileşenler); açık/koyu/sistem **görünüm** seçimi (NSApp.appearance).
- Lokalizasyon: Türkçe / İngilizce / İspanyolca / Fransızca (4 dil), Ayarlar'dan
  anlık dil değişimi; eksiklik + placeholder testleriyle korunur.
- **Geliştirici** temizleme kategorisi (Xcode DerivedData, npm/pip/poetry).
- **Disk analizi / büyük dosya bulucu** (salt-okunur tarama; Finder'da göster;
  silme yalnızca korumalı `app-clean` üzerinden ve **her zaman Çöp Kutusu'na**).
- **Zamanlanmış otomatik temizleme**: AI aracı başına saatlik (N saatte bir) /
  günlük / haftalık (haftanın günü) / aylık (ayın günü, saat:dakika); ayrı
  panelde düzenlenir, **Kaydet** ile uygulanır.
- **launchd ajanları**: zamanlanmış temizlik uygulama kapalıyken de çalışır;
  başarıda yerel bildirim.
- Toplam kazanılan alan istatistiği; satır-başı boyut çubukları; ikon
  önbellekleme.
- Erişilebilirlik: VoiceOver etiketleri, Reduce Motion, daha büyük dokunma
  alanları.

### Fixed (v2)
- Silme sırasında menü-bar panelinin kapanması (Ayarlar/Otomasyon/Disk analizi
  artık kendi gerçek pencerelerinde açılır); uninstall onayı panel içi.
- Silme akışındaki çökme (`availableData` → throwing `read`), "0 KB boşaltıldı"
  yarışı, başarısız silmelerin sessizce yutulması, `json_string` kontrol-karakter
  kaçışı; AI/Sistem sekmelerinin birbirine sızması.

### Engineering (v2)
- Motor: `auto-clean`, `analyze` alt-komutları; `safe_remove` koruma geçişi.
- CI/dağıtım: imzalı + notarized sürüm (graceful fallback), Homebrew cask,
  açılış sayfası; genişletilmiş bats + self-test kapsamı.
