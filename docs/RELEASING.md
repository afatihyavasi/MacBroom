# MacBroom Sürüm Yayınlama Rehberi

MacBroom GPL-3.0 lisanslı olduğu için **App Store'da dağıtılmaz**. Dağıtım üç
kanaldan yapılır:

1. **Notarized DMG** — GitHub Releases üzerinde imzalı + notarize edilmiş `.dmg`.
2. **Homebrew Cask** — `Casks/macbroom.rb` (`brew install --cask macbroom`).
3. **Landing page** — GitHub Pages (`docs/site/`).

---

## Sürüm çıkarma akışı

Yeni sürüm `v*` etiketi push'lanınca otomatik çalışır:

```bash
git tag v2.0.0
git push origin v2.0.0
```

Bu, `.github/workflows/release.yml` akışını tetikler. Akış:

1. `.app` paketini oluşturur (`scripts/make-app.sh`).
2. Secret'lar tanımlıysa Developer ID ile **imzalar** (hardened runtime + timestamp).
3. DMG oluşturur (`scripts/make-dmg.sh`).
4. Secret'lar tanımlıysa `notarytool` ile **notarize** eder ve ticket'ı **staple** eder.
5. DMG'yi GitHub Releases'e yükler.

> **Graceful fallback:** İmzalama/notarization secret'ları YOKSA akış yine de
> çalışır ve **imzasız** bir DMG üretir; CI başarısız olmaz. İmzasız DMG'yi
> kullanıcılar açarken "sağ tık → Aç" yapmak zorunda kalır.

---

## Gerekli secret'lar

Repo ayarlarında tanımlanır: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Açıklama |
|--------|----------|
| `MACOS_CERTIFICATE` | "Developer ID Application" sertifikasının `.p12` halinin base64 kodu |
| `MACOS_CERTIFICATE_PWD` | `.p12` dışa aktarımında verilen parola |
| `MACOS_SIGN_IDENTITY` | İmza kimliği, örn. `Developer ID Application: Ad Soyad (TEAMID)` |
| `AC_API_KEY` | App Store Connect API anahtarının (`.p8`) base64 kodu |
| `AC_API_KEY_ID` | API anahtarı ID'si (örn. `ABCD1234EF`) |
| `AC_API_ISSUER_ID` | App Store Connect issuer ID (UUID) |

---

## Secret'ları nasıl edinirsiniz

### 1. Developer ID sertifikası (`MACOS_CERTIFICATE`, `MACOS_CERTIFICATE_PWD`, `MACOS_SIGN_IDENTITY`)

Apple Developer Program üyeliği gerekir (yıllık ücretli).

1. **Xcode → Settings → Accounts → Manage Certificates → "+" → Developer ID Application**
   ile sertifika oluşturun (veya [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates) üzerinden).
2. **Keychain Access** uygulamasında bu sertifikayı (özel anahtarıyla birlikte)
   seçin → sağ tık → **Export** → `.p12` formatında dışa aktarın, bir parola verin.
   Bu parola → `MACOS_CERTIFICATE_PWD`.
3. `.p12` dosyasını base64'e çevirip kopyalayın:
   ```bash
   base64 -i Certificates.p12 | pbcopy
   ```
   Bu değer → `MACOS_CERTIFICATE`.
4. İmza kimliğini öğrenin:
   ```bash
   security find-identity -v -p codesigning
   ```
   Çıktıdaki `Developer ID Application: ... (TEAMID)` satırı → `MACOS_SIGN_IDENTITY`.

### 2. App Store Connect API anahtarı (`AC_API_KEY`, `AC_API_KEY_ID`, `AC_API_ISSUER_ID`)

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
   bölümüne gidin.
2. **Generate API Key** ile bir anahtar oluşturun (rol: **Developer** yeterli).
3. Oluşan **Key ID** → `AC_API_KEY_ID`.
4. Sayfanın üstündeki **Issuer ID** (UUID) → `AC_API_ISSUER_ID`.
5. `.p8` dosyasını indirin (yalnızca bir kez indirilebilir), base64'e çevirin:
   ```bash
   base64 -i AuthKey_ABCD1234EF.p8 | pbcopy
   ```
   Bu değer → `AC_API_KEY`.

---

## Yerelde test (isteğe bağlı)

```bash
make app VERSION=2.0.0     # build/MacBroom.app
make dmg VERSION=2.0.0     # build/MacBroom-2.0.0.dmg
```

İsteğe bağlı yerel imzalama, `make-app.sh` içinde `MACBROOM_SIGN_IDENTITY` ortam
değişkeni ayarlıysa devreye girer (ayarlı değilse davranış değişmez):

```bash
MACBROOM_SIGN_IDENTITY="Developer ID Application: Ad Soyad (TEAMID)" \
  make app VERSION=2.0.0
```

---

## Homebrew Cask güncelleme

Her sürümde `Casks/macbroom.rb` içindeki `version` ve `sha256` güncellenir:

```bash
shasum -a 256 build/MacBroom-2.0.0.dmg
```

Çıkan hash'i cask'taki `sha256` alanına yazın. `<OWNER>` placeholder'ını
GitHub kullanıcı/organizasyon adınızla değiştirin.

## Otomatik güncelleme (Sparkle)

MacBroom, uygulama içi güncelleme için [Sparkle](https://sparkle-project.org)
kullanır (`SwiftPM` bağımlılığı; `make-app.sh` `Sparkle.framework`'ü `.app`'e
gömer). Ayarlar → **Güncellemeler** bölümünden elle denetlenir; arka planda
günde bir otomatik denetler (`SUEnableAutomaticChecks`).

### İlk kurulum (bir kez)
1. **İmzalama anahtarını üret** (özel anahtar Keychain'de saklanır):
   ```bash
   app/.build/artifacts/sparkle/Sparkle/bin/generate_keys
   ```
   Çıktıdaki **public** anahtarı `scripts/make-app.sh` içindeki `SUPublicEDKey`
   placeholder'ı yerine yazın (şu an üretimde olmayan bir placeholder var).
2. `SUFeedURL` zaten `releases/latest/download/appcast.xml`'e işaret ediyor.

### Her sürümde
1. DMG'yi üretin (`make-dmg.sh`) ve imzalayın/notarize edin (yukarıdaki adımlar).
2. **appcast.xml üretin + imzalayın** (DMG'lerin olduğu klasörü verin):
   ```bash
   scripts/make-appcast.sh build/
   ```
   Bu, Sparkle'ın `generate_appcast`'ini çağırır (her DMG'yi Keychain'deki özel
   anahtarla EdDSA imzalar).
3. **appcast.xml**'i DMG ile birlikte GitHub Release'e yükleyin (aynı klasörde),
   böylece `SUFeedURL` ona ulaşır.

> CI'da otomatikleştirmek için: özel anahtarı `SPARKLE_ED_PRIVATE_KEY` secret'ı
> olarak ekleyin, `release.yml`'de DMG adımından sonra `make-appcast.sh build/`
> çalıştırıp `appcast.xml`'i release varlıklarına ekleyin.

> Not: Güncellemenin yüklenebilmesi için uygulamanın **imzalı** olması gerekir
> (Developer ID); imzasız dev derlemelerde denetim çalışır ama yükleme yapılmaz.
