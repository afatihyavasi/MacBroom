.PHONY: help engine-test engine-lint app-build app-test app-run test app dmg clean-build

VERSION ?= 0.1.0

help:
	@echo "MacBroom — make targets"
	@echo "  engine-test   Run bats tests for the engine bridge"
	@echo "  engine-lint   Run shellcheck on the engine"
	@echo "  app-build     swift build the menu bar app"
	@echo "  app-test      run the framework-free Swift self-tests"
	@echo "  app-run       launch the menu bar app (swift run)"
	@echo "  test          engine-lint + engine-test + app-test"
	@echo "  app           assemble build/MacBroom.app (VERSION=$(VERSION))"
	@echo "  dmg           package build/MacBroom-<version>.dmg"

engine-test:
	bats engine/tests/

engine-lint:
	shellcheck -x engine/macbroom-engine.sh

app-build:
	cd app && swift build

app-test:
	cd app && swift run MacBroomSelfTest

app-run:
	cd app && swift run MacBroom

test: engine-lint engine-test app-test

app:
	bash scripts/make-app.sh $(VERSION)

dmg: app
	bash scripts/make-dmg.sh $(VERSION)

clean-build:
	rm -rf app/.build build dist
