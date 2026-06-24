# MacBroom Release Guide

Because MacBroom is licensed under GPL-3.0, it is **not distributed on the App Store**. Distribution is done through three
channels:

1. **Notarized DMG** — a signed + notarized `.dmg` on GitHub Releases.
2. **Homebrew Cask** — `Casks/macbroom.rb` (`brew install --cask macbroom`).
3. **Landing page** — GitHub Pages (`docs/site/`).

---

## Release flow

It runs automatically when a new `v*` tag is pushed:

```bash
git tag v2.0.0
git push origin v2.0.0
```

This triggers the `.github/workflows/release.yml` workflow. The workflow:

1. Builds the `.app` bundle (`scripts/make-app.sh`).
2. **Signs** it with a Developer ID if the secrets are defined (hardened runtime + timestamp).
3. Creates the DMG (`scripts/make-dmg.sh`).
4. **Notarizes** it with `notarytool` and **staples** the ticket if the secrets are defined.
5. Uploads the DMG to GitHub Releases.

> **Graceful fallback:** If the signing/notarization secrets are NOT present, the workflow still
> runs and produces an **unsigned** DMG; CI does not fail. When opening an unsigned DMG,
> users have to "right-click → Open".

---

## Required secrets

These are defined in the repository settings: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Description |
|--------|----------|
| `MACOS_CERTIFICATE` | base64 encoding of the `.p12` form of the "Developer ID Application" certificate |
| `MACOS_CERTIFICATE_PWD` | the password set during the `.p12` export |
| `MACOS_SIGN_IDENTITY` | the signing identity, e.g. `Developer ID Application: Full Name (TEAMID)` |
| `AC_API_KEY` | base64 encoding of the App Store Connect API key (`.p8`) |
| `AC_API_KEY_ID` | the API key ID (e.g. `ABCD1234EF`) |
| `AC_API_ISSUER_ID` | the App Store Connect issuer ID (UUID) |

---

## How to obtain the secrets

### 1. Developer ID certificate (`MACOS_CERTIFICATE`, `MACOS_CERTIFICATE_PWD`, `MACOS_SIGN_IDENTITY`)

An Apple Developer Program membership is required (paid annually).

1. Create a certificate via **Xcode → Settings → Accounts → Manage Certificates → "+" → Developer ID Application**
   (or through [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)).
2. In the **Keychain Access** application, select this certificate (together with its private key)
   → right-click → **Export** → export it in `.p12` format and set a password.
   This password → `MACOS_CERTIFICATE_PWD`.
3. Convert the `.p12` file to base64 and copy it:
   ```bash
   base64 -i Certificates.p12 | pbcopy
   ```
   This value → `MACOS_CERTIFICATE`.
4. Find the signing identity:
   ```bash
   security find-identity -v -p codesigning
   ```
   The `Developer ID Application: ... (TEAMID)` line in the output → `MACOS_SIGN_IDENTITY`.

### 2. App Store Connect API key (`AC_API_KEY`, `AC_API_KEY_ID`, `AC_API_ISSUER_ID`)

1. Go to [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Create a key via **Generate API Key** (the **Developer** role is sufficient).
3. The resulting **Key ID** → `AC_API_KEY_ID`.
4. The **Issuer ID** (UUID) at the top of the page → `AC_API_ISSUER_ID`.
5. Download the `.p8` file (it can only be downloaded once) and convert it to base64:
   ```bash
   base64 -i AuthKey_ABCD1234EF.p8 | pbcopy
   ```
   This value → `AC_API_KEY`.

---

## Local testing (optional)

```bash
make app VERSION=2.0.0     # build/MacBroom.app
make dmg VERSION=2.0.0     # build/MacBroom-2.0.0.dmg
```

Optional local signing kicks in if the `MACBROOM_SIGN_IDENTITY` environment
variable is set inside `make-app.sh` (if it is not set, the behavior does not change):

```bash
MACBROOM_SIGN_IDENTITY="Developer ID Application: Full Name (TEAMID)" \
  make app VERSION=2.0.0
```

---

## Updating the Homebrew Cask

For each release, update the `version` and `sha256` in `Casks/macbroom.rb`:

```bash
shasum -a 256 build/MacBroom-2.0.0.dmg
```

Write the resulting hash into the `sha256` field of the cask. Replace the `<OWNER>` placeholder
with your GitHub user/organization name.

---

## Publishing the Homebrew tap

`brew install --cask afatihyavasi/tap/macbroom` resolves to a GitHub repo named
**`afatihyavasi/homebrew-tap`** (Homebrew strips the `homebrew-` prefix). The cask
file must live there, not in this repo. One-time setup:

```bash
# 1. Create the tap repo (GitHub CLI). Must be named exactly homebrew-tap.
gh repo create afatihyavasi/homebrew-tap --public \
  -d "Homebrew tap for MacBroom"

# 2. Clone it and add the cask under Casks/.
git clone https://github.com/afatihyavasi/homebrew-tap.git
mkdir -p homebrew-tap/Casks
cp Casks/macbroom.rb homebrew-tap/Casks/macbroom.rb

# 3. Commit and push.
cd homebrew-tap
git add Casks/macbroom.rb
git commit -m "macbroom 0.1.0-beta"
git push
```

Now anyone can install with:

```bash
brew install --cask afatihyavasi/tap/macbroom
```

**On each release**, bump `version` + `sha256` in `homebrew-tap/Casks/macbroom.rb`
and push. For **unsigned** beta builds, add `no_quarantine true` to the cask so
Homebrew skips the Gatekeeper prompt:

```ruby
  app "MacBroom.app"
  no_quarantine true   # remove once releases are notarized
```
