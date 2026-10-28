# Portão de qualidade. Ver docs/CONVENTIONS.md.

# Explicit source dirs, never bare `Packages` — recursing there would descend
# into .build/ and lint vendored code.
SWIFT_PATHS := $(wildcard Packages/*/Package.swift Packages/*/Sources Packages/*/Tests App tools)
PACKAGE := Packages/PianovaCore

IPAD := 9A198D1D-47F0-56DD-9CDC-DE91D15D593D

# O identificador do app. Mudou de com.pianova.app para br.com.pianova.app
# e o antigo ficou no Makefile: o launch dizia "não está instalado" e a
# cópia de partituras falhava com ContainerLookupError, as duas sem dizer
# por quê. Um lugar só para essa string.
BUNDLE = br.com.pianova.app
APP := $(HOME)/Library/Developer/Xcode/DerivedData/Pianova-egvzptomtwyroifikvadsgmlsyxx/Build/Products/Debug-iphoneos/Pianova.app

.PHONY: format lint test check ipad

format:
	xcrun swift-format format --in-place --recursive --parallel $(SWIFT_PATHS)

lint:
	xcrun swift-format lint --strict --recursive --parallel $(SWIFT_PATHS)

test:
	swift test --package-path $(PACKAGE)

check: lint test

# Reassina, reinstala e abre no iPad físico — renova a janela de 7 dias da
# conta gratuita. Exige o Apple ID logado no Xcode (Settings > Accounts).
ipad:
	xcodebuild -project App/Pianova.xcodeproj -scheme Pianova \
		-destination "id=$(IPAD)" -configuration Debug \
		-allowProvisioningUpdates build
	xcrun devicectl device install app --device $(IPAD) "$(APP)"
	xcrun devicectl device process launch --device $(IPAD) $(BUNDLE)
