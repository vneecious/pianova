# Portão de qualidade. Ver docs/CONVENTIONS.md.

# Explicit source dirs, never bare `Packages` — recursing there would descend
# into .build/ and lint vendored code.
SWIFT_PATHS := $(wildcard Packages/*/Package.swift Packages/*/Sources Packages/*/Tests App tools)
PACKAGE := Packages/PianovaCore

.PHONY: format lint test check

format:
	xcrun swift-format format --in-place --recursive --parallel $(SWIFT_PATHS)

lint:
	xcrun swift-format lint --strict --recursive --parallel $(SWIFT_PATHS)

test:
	swift test --package-path $(PACKAGE)

check: lint test
