# Contributing to MacBroom

Thank you! MacBroom is an open-source (GPL-3.0) project.

## Development environment

```bash
git clone --recurse-submodules <repo>
cd macbroom
# Bridge engine
shellcheck engine/macbroom-engine.sh
bats engine/tests/
# App
swift build && swift test
```

## Rules

- **Safety critical.** Every PR that touches deletion logic must include a bats test proving the dry-run behavior and that protected paths (auth/sessions/memory) are **not deleted**.
- The mole `vendor/` submodule is **never modified directly**; fixes are submitted upstream. Version bumps go in a separate commit.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `chore:`, `docs:`, `ci:`.
- Swift: `swift-format` / 4 spaces. Shell: `shellcheck` must be clean.

## Updating the mole submodule

```bash
cd vendor/mole && git fetch && git checkout <new-tag>
cd ../.. && git add vendor/mole && git commit -m "chore: bump mole to <tag>"
```

## License

Your contributions are licensed under GPL-3.0-or-later.
