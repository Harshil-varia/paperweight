.PHONY: generate build test clean help

help:
	@echo "Paperweight build targets:"
	@echo "  make generate   - Generate Xcode project from project.yml"
	@echo "  make build      - Build the Paperweight app"
	@echo "  make test       - Run unit tests"
	@echo "  make clean      - Clean build artifacts"

generate:
	xcodegen generate

build: generate
	xcodebuild -scheme Paperweight build

test: generate
	xcodebuild test -scheme Paperweight

clean:
	rm -rf build Paperweight.xcodeproj
