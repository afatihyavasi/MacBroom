# MacBroom Mimarisi

## Katmanlar

```
┌─────────────────────────────────────────────┐
│  MacBroom.app  (SwiftUI, MenuBarExtra)        │  native UI
│  Views / ViewModels / Models / EngineBridge   │
└───────────────┬─────────────────────────────┘
                │ Process spawn · stdin yok · stdout: JSON (sonuç) + NDJSON (ilerleme)
┌───────────────▼─────────────────────────────┐
│  engine/macbroom-engine.sh   (köprü, GPL-3.0) │
│  alt komutlar: scan | clean | status |        │
│                ai-scan | ai-clean | version    │
└───────────────┬─────────────────────────────┘
                │ source (bash)
┌───────────────▼─────────────────────────────┐
│  vendor/mole/  (git submodule · pinned tag)   │
│  lib/core/*.sh  lib/clean/*.sh  cmd/* (Go)     │
└─────────────────────────────────────────────┘
```

## Neden köprü script?

mole'un `clean`/`uninstall` komutları **etkileşimlidir** (TTY prompt'ları, `-t 1` kontrolleri) ve `--json` çıktısı yoktur; ayrıca monolitiktir (kategori seçimi yok). Menü çubuğu uygulaması ise:
- kategori/öğe-bazlı seçmeli kontrol,
- yapısal (JSON) veri,
- non-interactive çalışma ister.

Bunu sağlamanın en sağlam yolu, mole'un etkileşimli giriş noktalarını taklit etmek yerine, `lib/clean/*.sh` içindeki **fonksiyonları doğrudan source edip** `DRY_RUN`/non-interactive çağırmaktır. Böylece mole'un denetlenmiş silme primitifi `safe_clean` ve koruma katmanı `should_protect_path` aynen korunur; sadece UI/protokol katmanı eklenir.

## Köprü protokolü

- **stdout son satır(lar)**: tek bir JSON nesnesi (komut sonucu).
- **ara satırlar (NDJSON)**: `{"event":"progress", ...}` ilerleme olayları (uzun süren `clean` için).
- **çıkış kodu**: 0 başarı, !=0 hata; hata JSON'u `{"error": "..."}`.

### Komutlar
| Komut | Çıktı | Açıklama |
|-------|-------|----------|
| `scan --categories=ai,system` | `{candidates:[{category,label,path,size_bytes,protected,reason}]}` | dry-run tarama |
| `clean --paths-file=F` | NDJSON progress + `{freed_bytes,count}` | seçili yolları siler |
| `ai-scan` | AI araç-bazlı aday listesi | F1 için özel |
| `ai-clean --tools=codex,gemini` | progress + özet | AI cache temizliği |
| `status` | `{disk,cpu,memory,cleanable_bytes}` | mole status metrikleri |
| `version` | `{macbroom,mole}` | sürümler |

## Swift tarafı

- `EngineBridge`: `Process` ile bundle'lanmış scripti çalıştırır; satır-bazlı okur; JSON `Decodable` modellerine çözer; ilerlemeyi `AsyncStream` ile yayar.
- Engine + `vendor/mole` build sırasında `.app/Contents/Resources/engine/` altına kopyalanır; script'e çalıştırma izni verilir.

## Dağıtım

Notarized DMG (Developer ID). Sandbox YOK — temizleyici için Full Disk Access gerekir. İlk açılışta onboarding kullanıcıyı Sistem Ayarları > Gizlilik & Güvenlik > Full Disk Access'e yönlendirir.
