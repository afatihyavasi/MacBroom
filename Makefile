.PHONY: help engine-test engine-lint app-build app-test test clean-build

help:
	@echo "MacBroom — make targets"
	@echo "  engine-test   Run bats tests for the engine bridge"
	@echo "  engine-lint   Run shellcheck on the engine"
	@echo "  app-build     swift build the menu bar app"
	@echo "  app-test      swift test"
	@echo "  test          engine-lint + engine-test + app-test"

engine-test:
	bats engine/tests/

engine-lint:
	shellcheck -x engine/macbroom-engine.sh

app-build:
	cd app && swift build

app-test:
	cd app && swift test

test: engine-lint engine-test app-test

clean-build:
	rm -rf app/.build build dist
