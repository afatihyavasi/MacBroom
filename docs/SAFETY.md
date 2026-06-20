# MacBroom Güvenlik Modeli

MacBroom yıkıcı (silme) işlemleri yapabilir. Tasarım, **güvenli-varsayılan** ilkesine dayanır ve mole'un güvenlik katmanını miras alır.

## Çok katmanlı koruma

1. **Dry-run zorunlu** — her temizlik önce önizlenir; kullanıcı görmeden hiçbir şey silinmez.
2. **mole `should_protect_path` / `should_protect_data`** — sistem-kritik yollar, korunan uygulama verileri reddedilir.
3. **Whitelist** — `~/Library/Caches/com.apple.Spotlight*`, JetBrains, `.ollama/models` gibi yeniden-pahalı yollar varsayılan korunur.
4. **Path-traversal reddi** — `..` içeren veya mutlak olmayan yollar reddedilir; `/`, `/System`, `/bin`, `/usr` vb. her zaman korunur.
5. **Açık onay** — silmeden önce ayrı bir onay adımı.

## AI araçları: state asla varsayılan silinmez

| Araç | Korunan (DOKUNULMAZ) | Temizlenebilir (güvenli) |
|------|----------------------|--------------------------|
| **Codex** (`~/.codex`) | `auth.json`, `sessions/`, `history.jsonl`, `*.sqlite`, `session_index.jsonl` | runtime/geçici dosyalar |
| **Claude** (`~/.claude`, `~/Library/Application Support/Claude`) | `memory/`, projeler, `.claude/worktrees`, auth | eski bundled Desktop sürümleri, yeniden üretilebilir cache |
| **Gemini** (`~/.gemini`) | kimlik/state | `tmp/`, `antigravity-browser-profile/` |
| **Cursor** | proje verisi, auth | agent session logları |

Ek koruma: **araç çalışıyorsa** (`pgrep` ile tespit) o araç atlanır ve kullanıcı uyarılır.

## "İleri" (state) temizliği

state içeren ileri temizlik seçenekleri UI'da **varsayılan kapalıdır**, ayrı ve açık bir onay gerektirir, ve risk net biçimde belirtilir.

## Gizlilik

- Tümüyle yerel çalışır; ağ bağlantısı / telemetri yoktur.
- Silme geçmişi mole `history` ile yerelde tutulur; UI'dan görüntülenebilir.
