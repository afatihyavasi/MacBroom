# MacBroom — Hata Analizi, Performans ve Çözüm Planı

Tarih: 2026-06-20

## Kullanıcı raporu
"Uygulamayı silmek istediğimde *Kalıcı olarak sil*'e bastığımda uygulama
kapanıyor." Bu bir **çökme (crash)**, izin sorunu değil — ancak izin sorunu da
ayrı bir gizli hata olarak mevcut (sessizce yutuluyor). İkisi de aşağıda.

---

## Bulunan hatalar (önem sırasına göre)

### P0 — Silme sırasında uygulamanın çökmesi (KÖK NEDEN)
`app/Sources/MacBroomCore/EngineBridge.swift` → `streamingClean(...)`

- `pipe.fileHandleForReading.readabilityHandler` içinde `handle.availableData`
  kullanılıyor. Alt-süreç (engine) bittiğinde pipe'ın okuma ucu kapanır ve bu
  sırada gelen son okuma `NSFileHandleOperationException: Bad file descriptor`
  **Objective-C istisnası** fırlatır.
- Swift bu ObjC istisnasını `try/catch` ile yakalayamaz → `SIGABRT` →
  **tüm menü-bar uygulaması anında kapanır.**
- `terminationHandler` `readabilityHandler = nil` yaparken okuma hâlâ uçuşta
  olduğundan yarış (race) durumu neredeyse her seferinde tetiklenir; app-clean
  hızlı bittiği için kullanıcı bunu "her zaman çöküyor" olarak görür.
- Aynı kod `clean` (önbellek temizleme) için de kullanılıyor → o akış da riskli.

**Çözüm:** `availableData` yerine Swift-throwing `read(upToCount:)` kullan
(ObjC istisnası yerine Swift hatası döndürür), `continuation.finish()`'i
kilitli tek-seferlik (one-shot) yap, `proc.run()` hatasını ayrıca ele al.

### P1 — İzin/başarısız silme sessizce yutuluyor (kullanıcıya bildirim yok)
`engine/macbroom-engine.sh` → `_mb_remove` `rm -rf -- "$1" 2>/dev/null`

- Uygulama `/Applications` altında root'a aitse veya Tam Disk Erişimi yoksa
  `rm` başarısız olur, hata `2>/dev/null` ile yutulur, öğe sadece atlanır.
- UI "Kaldırıldı" der ama aslında hiçbir şey silinmemiş olabilir → kullanıcı
  yanıltılır. Kullanıcının "izinle alakalıysa bildir" isteği tam buraya denk.

**Çözüm:** Engine başarısız silmede `{"event":"skipped",...,"reason":...}`
yayınlar; `EngineEvent`'e `.skipped` eklenir; `AppState` başarısızları sayar;
`UninstallView` "N öğe silinemedi — Tam Disk Erişimi gerekebilir" + ayar butonu
gösterir.

### P2 — Akışta küçük dayanıklılık/performans sorunları
- Son satır `\n` ile bitmezse tampon (buffer) boşaltılmıyor → "done" olayı
  kaybolabilir (toplam `freed` yine progress'lerden toplanıyor, kozmetik).
- `du` zaten kaldırılmış (hızlı liste); app-scan boyutlandırması büyük
  uygulamalarda yavaş olabilir — gelecekte arka planda boyutlandırma.

---

## Uygulama sırası
1. **P0 crash fix** — EngineBridge streaming'i güvenli oku. ✅ (bu turda)
2. **P1 permission feedback** — engine + model + state + view. ✅ (bu turda)
3. **P2** — tampon flush. ✅ (bu turda, küçük)
