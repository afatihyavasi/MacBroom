<div align="center">

# 🧹 MacBroom

**macOS menü çubuğu için güvenli, açık kaynak sistem & AI cache temizleyici.**

Powered by [`tw93/mole`](https://github.com/tw93/mole) · SwiftUI · GPL-3.0

</div>

---

## Nedir?

MacBroom, [mole](https://github.com/tw93/mole) CLI'ının güvenlik-öncelikli temizleme motorunu, Mac tasarım diline uygun bir **menü çubuğu uygulamasının** arkasına koyar. Terminal gerekmez.

Öne çıkan özellik: **Codex, Claude, Gemini ve Cursor** gibi AI araçlarının cache dosyalarını — kimlik/oturum/hafıza verilerine **dokunmadan** — güvenle temizler.

## Özellikler

- 🤖 **AI cache temizliği** — Codex / Claude / Gemini / Cursor; state korunur, sadece yeniden üretilebilir cache silinir.
- 🧽 **Sistem cache temizliği** — dry-run önizleme + açık onay ile.
- 📊 **Disk & sistem durumu** — menü çubuğunda canlı.
- 🗑️ **App uninstaller** — uygulama + kalıntıları.

## Güvenlik

MacBroom hiçbir şeyi önizleme ve onay olmadan silmez. Tüm silmeler mole'un `should_protect_path`, whitelist ve path-traversal korumalarından geçer. AI araçlarının auth/sessions/memory/history verileri **varsayılan korunur**. Ayrıntı: [`docs/SAFETY.md`](docs/SAFETY.md).

## Kurulum (geliştirme)

```bash
git clone --recurse-submodules https://github.com/<you>/macbroom.git
cd macbroom
swift build           # uygulama
bats engine/tests/    # köprü testleri
```

> Notarized DMG sürümleri Releases sayfasından gelecektir.

## Mimari

```
MacBroom.app (SwiftUI MenuBarExtra)
   │  Process + JSON/NDJSON
engine/macbroom-engine.sh (mole lib'ini source eder)
   │
vendor/mole (git submodule, pinned V1.43.1)
```

Ayrıntı: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · Ürün gereksinimleri: [`PRD.md`](PRD.md).

## Lisans & Atıf

MacBroom, mole'un GPL-3.0 lisanslı `lib/` modüllerini kullandığı için **GPL-3.0-or-later** altında dağıtılır. Temizleme motoru ve güvenlik tasarımı için [tw93/mole](https://github.com/tw93/mole)'a teşekkürler.
