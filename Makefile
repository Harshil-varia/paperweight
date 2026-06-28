.PHONY: generate build test clean help release notarize icon install

help:
	@echo "Paperweight build targets:"
	@echo "  make generate   - Generate Xcode project from project.yml"
	@echo "  make build      - Build the Paperweight app"
	@echo "  make test       - Run unit tests"
	@echo "  make icon       - Regenerate app icon + menu-bar glyph from SVG sources"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make release    - Build release .app (ad-hoc signed) and a DMG"
	@echo "  make install    - Install the release build into /Applications"
	@echo "  make notarize   - Sign and notarize (requires IDENTITY env var)"

icon:
	./scripts/generate-icon.sh

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme Paperweight build

test: generate
	xcodebuild test -scheme Paperweight

clean:
	rm -rf build Paperweight.xcodeproj

release: generate
	@echo "Building Paperweight release build..."
	xcodebuild -scheme Paperweight -configuration Release \
		-derivedDataPath build/DerivedData clean build
	@echo "Assembling .app..."
	@mkdir -p build/Release
	@APP_PATH=build/DerivedData/Build/Products/Release/Paperweight.app; \
		if [ ! -d "$$APP_PATH" ]; then \
			echo "Error: Could not find built app at $$APP_PATH"; exit 1; \
		fi; \
		rm -rf build/Release/Paperweight.app; \
		cp -r "$$APP_PATH" build/Release/Paperweight.app; \
		if [ ! -f build/Release/Paperweight.app/Contents/Resources/Assets.car ]; then \
			echo "Error: assembled .app is missing Assets.car (compiled AppIcon)"; exit 1; \
		fi
	@echo "Ad-hoc signing (no paid Developer account needed for local/internal use)..."
	@codesign --force --deep --sign - build/Release/Paperweight.app
	@codesign --verify --verbose=1 build/Release/Paperweight.app
	@echo "Creating DMG..."
	@mkdir -p build/dmg-tmp
	@cp -r build/Release/Paperweight.app build/dmg-tmp/Paperweight.app
	@cp scripts/install.sh build/dmg-tmp/install.sh
	@chmod +x build/dmg-tmp/install.sh
	@ln -s /Applications build/dmg-tmp/Applications 2>/dev/null || true
	@hdiutil create -volname "Paperweight" -srcfolder build/dmg-tmp \
		-ov -format UDZO build/Release/Paperweight.dmg
	@rm -rf build/dmg-tmp
	@echo "Release complete:"
	@echo "  .app: $(shell pwd)/build/Release/Paperweight.app"
	@echo "  DMG:  $(shell pwd)/build/Release/Paperweight.dmg"

install:
	@APP=build/Release/Paperweight.app; \
		if [ ! -d "$$APP" ]; then echo "No release build found. Run 'make release' first."; exit 1; fi; \
		echo "Quitting any running Paperweight..."; \
		osascript -e 'tell application "Paperweight" to quit' 2>/dev/null || true; \
		echo "Installing to /Applications/Paperweight.app..."; \
		rm -rf /Applications/Paperweight.app; \
		cp -r "$$APP" /Applications/Paperweight.app; \
		echo "Clearing quarantine flag (unsigned local build)..."; \
		xattr -dr com.apple.quarantine /Applications/Paperweight.app 2>/dev/null || true; \
		echo "Installed. Launch from Spotlight or: open -a Paperweight"

notarize:
	@if [ -z "$(IDENTITY)" ]; then \
		echo "Error: IDENTITY env var not set (e.g., IDENTITY='Developer ID Application: Name')"; \
		exit 1; \
	fi
	@echo "Signing Paperweight with identity: $(IDENTITY)"
	codesign --force --verify --verbose --sign "$(IDENTITY)" build/Release/Paperweight.app
	@echo "Submitting for notarization..."
	@echo "Note: Full notarization requires an Apple Developer account and credentials."
	@echo "For local ad-hoc builds, see README.md for unsigned launch instructions."
