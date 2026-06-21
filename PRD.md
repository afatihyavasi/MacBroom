# MacBroom — Product Requirements Document (PRD)

> macOS menü çubuğu için güvenli, açık kaynak sistem & AI cache temizleyici.
> Motor olarak [`tw93/mole`](https://github.com/tw93/mole) (GPL-3.0) kullanır.

- **Durum:** Taslak v0.1 · 2026-06-20
- **Lisans:** GPL-3.0-or-later (mole türevi)
- **Platform:** macOS 13+ (Apple Silicon & Intel)
- **Dağıtım:** Notarized DMG (sandbox dışı, Full Disk Access)

---

## 1. Problem & Vizyon

macOS zamanla cache, log, tarayıcı kalıntısı ve özellikle **AI geliştirme araçlarının** (Codex, Claude, Gemini, Cursor) ürettiği büyük cache dosyalarıyla dolar. Mevcut çözümler ya kapalı kaynak/ücretli (CleanMyMac), ya da terminal bilgisi gerektirir (mole CLI).

**Vizyon:** mole'un savaş-test edilmiş, güvenlik-öncelikli temizleme motorunu, Mac tasarım diline uygun bir **menü çubuğu uygulamasının** arkasına koymak. Tek tık ile güvenli önizleme ve temizlik; AI araç cache'leri birinci sınıf özellik.

## 2. Hedef Kitle

- AI araçlarını yoğun kullanan geliştiriciler (cache'ler hızla GB'lara ulaşır).
- Terminal istemeyen, görsel ve güvenli temizlik isteyen Mac kullanıcıları.

## 3. Hedefler / Hedef Olmayanlar

**Hedefler (MVP)**
1. AI araç cache'lerinin **güvenli** temizliği (state'e dokunmadan).
2. Sistem cache temizliği (dry-run önizleme + onay).
3. Disk/sistem durumu paneli.
4. App uninstaller (kalıntılarıyla).

**Hedef değil (şimdilik)**
- Mac App Store sürümü (GPL-3.0 + Tam Disk Erişimi → sandbox kısıtları).
- Windows/Linux.

> Not: Zamanlanmış otomatik temizlik ve disk analizi **v2'de gönderildi**
> (aşağıdaki yol haritasına bakın).

## 4. Temel İlkeler

1. **Güvenlik önce gelir.** Hiçbir şey önizleme (dry-run) ve açık onay olmadan silinmez. mole'un `should_protect_path` / whitelist / path-traversal korumaları korunur.
2. **State asla varsayılan silinmez.** AI araçlarının kimlik (auth), oturum (sessions), hafıza (memory), geçmiş (history) verileri varsayılan olarak korunur.
3. **Şeffaflık.** Her aday dosya: yol + boyut + neden + kategori ile listelenir.
4. **Native his.** macOS tasarım dili (MenuBarExtra, SF Symbols, materyal).

## 5. Mimari (özet)

```
MacBroom.app (SwiftUI MenuBarExtra)
   │  Process + JSON/NDJSON
macbroom-engine.sh (köprü, mole lib'ini source eder)
   │  source
vendor/mole/ (git submodule, pinned: V1.43.1)
```

Köprü, mole'un etkileşimli `clean` komutunu değil, `lib/clean/*.sh` içindeki fonksiyonları **non-interactive + DRY_RUN** çağırarak JSON üretir. Bu, kategori-bazlı seçmeli kontrol ve kırılgan TUI scraping'den kaçınma sağlar.

## 6. Özellik Gereksinimleri

### F1 — AI Cache Temizliği (P0)
- Araç-bazlı kartlar: **Codex, Claude (Code + Desktop), Gemini, Cursor**.
- Her araç için "Güvenli (cache)" vs "İleri (state)" ayrımı; ikincisi varsayılan kapalı + ayrı onay.
- Çalışan araç tespiti (`pgrep`) → çalışıyorsa atla/uyar.
- Korunan: Codex `auth.json`/`sessions/`/`history.jsonl`/`*.sqlite`; Claude `memory/`/projeler/`.claude/worktrees`/auth; Gemini kimlik/state.
- Temizlenen (güvenli): Gemini `tmp/` & `antigravity-browser-profile/`, codex runtimes, eski Claude Desktop bundled sürümleri, Cursor agent session logları.

### F2 — Sistem Cache Temizliği (P0)
- Kategoriler (mole `lib/clean/*`): user caches, app caches, logs, browser leftovers, .DS_Store, dev caches.
- Dry-run önizleme zorunlu → kategori/öğe seçimi → onay → canlı ilerleme → "X GB boşaltıldı" özeti.

### F3 — Disk/Sistem Durumu (P1)
- Menü çubuğu ikonunda disk doluluk yüzdesi/rozet.
- Panel: disk kullanımı, temizlenebilir tahmini alan, CPU/RAM (mole `status`).

### F4 — App Uninstaller (P1)
- Yüklü uygulamalar + kalıntı tarama (Application Support, Caches, Preferences, Logs...).
- Seçmeli kaldırma + onay; sistem-kritik uygulamalar korunur.

## 7. Güvenlik & Gizlilik
- Tamamen yerel; ağ erişimi yok (telemetri yok).
- Tüm silmeler mole güvenlik katmanından geçer.
- Geçmiş/günlük: mole `history` ile kaydedilir; UI'dan görülebilir.
- Full Disk Access ilk açılışta açıkça istenir/yönlendirilir.

## 8. Başarı Metrikleri
- İlk taramadan temizliğe < 3 tık.
- Sıfır yanlış-pozitif state silme (test edilmiş).
- Dry-run önizleme < 5 sn (tipik makine).

## 9. Yol Haritası
- **v1.0 (MVP):** F1–F4, notarized DMG, CI.
- **v2 (gönderildi):** shadcn tasarım sistemi + açık/koyu tema; 4 dil (TR/EN/ES/FR);
  Geliştirici temizleme kategorisi; disk analizi / büyük dosya bulucu;
  zamanlanmış otomatik temizleme (saatlik/günlük/haftalık/aylık) + launchd ile
  uygulama kapalıyken çalışma + bildirim; erişilebilirlik; toplam kazanılan alan;
  Homebrew cask + imzalı/notarized sürüm + açılış sayfası.
- **Sonraki:** kurallar/whitelist UI; tarayıcı & bakım temizleme kategorileri;
  Sparkle otomatik güncelleme; temizlik geçmişi grafiği.

## 10. Atıf & Lisans
MacBroom, `tw93/mole`'un temizleme motorunu paketler ve onun `lib/` modüllerine bağımlıdır. Bu nedenle **GPL-3.0-or-later** altında dağıtılır. mole'a tam atıf README ve uygulama "Hakkında" ekranında yer alır.
