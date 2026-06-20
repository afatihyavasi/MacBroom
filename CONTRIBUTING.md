# MacBroom'a Katkı

Teşekkürler! MacBroom açık kaynak (GPL-3.0) bir projedir.

## Geliştirme ortamı

```bash
git clone --recurse-submodules <repo>
cd macbroom
# Köprü motoru
shellcheck engine/macbroom-engine.sh
bats engine/tests/
# Uygulama
swift build && swift test
```

## Kurallar

- **Güvenlik kritik.** Silme mantığına dokunan her PR, dry-run davranışını ve korunan yolların (auth/sessions/memory) **silinmediğini** kanıtlayan bats testi içermelidir.
- mole `vendor/` submodule'ü **doğrudan değiştirilmez**; düzeltmeler upstream'e gönderilir. Sürüm yükseltmeleri ayrı commit.
- Commit mesajları [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `chore:`, `docs:`, `ci:`.
- Swift: `swift-format` / 4 boşluk. Shell: `shellcheck` temiz olmalı.

## mole submodule güncelleme

```bash
cd vendor/mole && git fetch && git checkout <yeni-tag>
cd ../.. && git add vendor/mole && git commit -m "chore: bump mole to <tag>"
```

## Lisans

Katkılarınız GPL-3.0-or-later altında lisanslanır.
