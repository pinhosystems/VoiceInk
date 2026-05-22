# Sibling to the project so the dependency tree lives next to the repo
# instead of cluttering the user's home folder. Override DEPS_DIR on the
# make command line if you want it somewhere else.
DEPS_DIR ?= $(CURDIR)/../VoiceInk-Dependencies
WHISPER_CPP_DIR := $(DEPS_DIR)/whisper.cpp
FRAMEWORK_PATH := $(WHISPER_CPP_DIR)/build-apple/whisper.xcframework
LOCAL_DERIVED_DATA := $(CURDIR)/.local-build

# Local code-signing identity. When set to a real certificate in the
# login keychain, rebuilds keep their TCC grants (Accessibility, Screen
# Recording, etc.) because the Designated Requirement is stable across
# binary cdhashes. When set to "-" (ad-hoc), every rebuild invalidates
# every prior TCC grant. Run `make setup-signing` once to provision the
# default identity below.
LOCAL_SIGNING_IDENTITY ?= VoiceInk Local Dev

.PHONY: all clean whisper setup setup-signing build local install-local check healthcheck help dev run

# Default target
all: check build

# Development workflow
dev: build run

# Prerequisites
check:
	@echo "Checking prerequisites..."
	@command -v git >/dev/null 2>&1 || { echo "git is not installed"; exit 1; }
	@command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild is not installed (need Xcode)"; exit 1; }
	@command -v swift >/dev/null 2>&1 || { echo "swift is not installed"; exit 1; }
	@echo "Prerequisites OK"

healthcheck: check

# Build process
whisper:
	@mkdir -p $(DEPS_DIR)
	@if [ ! -d "$(FRAMEWORK_PATH)" ]; then \
		echo "Building whisper.xcframework in $(DEPS_DIR)..."; \
		if [ ! -d "$(WHISPER_CPP_DIR)" ]; then \
			git clone https://github.com/ggerganov/whisper.cpp.git $(WHISPER_CPP_DIR); \
		else \
			(cd $(WHISPER_CPP_DIR) && git pull); \
		fi; \
		cd $(WHISPER_CPP_DIR) && ./build-xcframework.sh; \
	else \
		echo "whisper.xcframework already built in $(DEPS_DIR), skipping build"; \
	fi

setup: whisper
	@echo "Whisper framework is ready at $(FRAMEWORK_PATH)"
	@echo "Please ensure your Xcode project references the framework from this new location."

build: setup
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug CODE_SIGN_IDENTITY="" build

# Build for local use without Apple Developer certificate.
#
# When LOCAL_SIGNING_IDENTITY points at a self-signed certificate
# present in the login keychain (default: "VoiceInk Local Dev",
# provisioned via `make setup-signing`), the build uses that identity
# so the Designated Requirement stays stable across rebuilds — TCC
# grants survive. Fall back to ad-hoc ("-") when the identity isn't
# found so the target keeps working on fresh checkouts.
local: check setup
	@echo "Building VoiceInk for local use..."
	@rm -rf "$(LOCAL_DERIVED_DATA)"
	@if security find-identity -p codesigning -v "${HOME}/Library/Keychains/login.keychain-db" 2>/dev/null | grep -qF "\"$(LOCAL_SIGNING_IDENTITY)\""; then \
		echo "Signing with stable identity: $(LOCAL_SIGNING_IDENTITY)"; \
		SIGN_IDENTITY="$(LOCAL_SIGNING_IDENTITY)"; \
		SIGN_REQUIRED="YES"; \
	else \
		echo "Identity '$(LOCAL_SIGNING_IDENTITY)' not found — falling back to ad-hoc."; \
		echo "(Run 'make setup-signing' once to get persistent TCC grants.)"; \
		SIGN_IDENTITY="-"; \
		SIGN_REQUIRED="NO"; \
	fi; \
	xcodebuild -project VoiceInk.xcodeproj -scheme VoiceInk -configuration Debug \
		-derivedDataPath "$(LOCAL_DERIVED_DATA)" \
		-xcconfig LocalBuild.xcconfig \
		CODE_SIGN_IDENTITY="$$SIGN_IDENTITY" \
		CODE_SIGNING_REQUIRED="$$SIGN_REQUIRED" \
		CODE_SIGNING_ALLOWED=YES \
		DEVELOPMENT_TEAM="" \
		CODE_SIGN_ENTITLEMENTS=$(CURDIR)/VoiceInk/VoiceInk.local.entitlements \
		SWIFT_ACTIVE_COMPILATION_CONDITIONS='$$(inherited) LOCAL_BUILD' \
		build
	@APP_PATH="$(LOCAL_DERIVED_DATA)/Build/Products/Debug/VoiceInk.app" && \
	if [ -d "$$APP_PATH" ]; then \
		echo "Copying VoiceInk.app to ~/Downloads..."; \
		rm -rf "$$HOME/Downloads/VoiceInk.app"; \
		ditto "$$APP_PATH" "$$HOME/Downloads/VoiceInk.app"; \
		xattr -cr "$$HOME/Downloads/VoiceInk.app"; \
		echo ""; \
		echo "Build complete! App saved to: ~/Downloads/VoiceInk.app"; \
		echo "Run with: open ~/Downloads/VoiceInk.app"; \
		echo ""; \
		echo "Limitations of local builds:"; \
		echo "  - No iCloud dictionary sync"; \
		echo "  - No automatic updates (pull new code and rebuild to update)"; \
	else \
		echo "Error: Could not find built VoiceInk.app at $$APP_PATH"; \
		exit 1; \
	fi

# Build, reset stale TCC grants, and replace /Applications/VoiceInk.app in one shot.
# See scripts/install-local.sh for the rationale and the one manual step left
# (re-adding the app to Accessibility/Screen Recording in System Settings).
install-local:
	@$(CURDIR)/scripts/install-local.sh

# Provision a stable, self-signed code-signing certificate in the login
# keychain so subsequent `make install-local` runs keep their TCC grants.
# Idempotent — re-running detects the existing identity. Pass --force
# to regenerate.
setup-signing:
	@$(CURDIR)/scripts/setup-local-signing.sh

# Run application
run:
	@if [ -d "$$HOME/Downloads/VoiceInk.app" ]; then \
		echo "Opening ~/Downloads/VoiceInk.app..."; \
		open "$$HOME/Downloads/VoiceInk.app"; \
	else \
		echo "Looking for VoiceInk.app in DerivedData..."; \
		APP_PATH=$$(find "$$HOME/Library/Developer/Xcode/DerivedData" -name "VoiceInk.app" -type d | head -1) && \
		if [ -n "$$APP_PATH" ]; then \
			echo "Found app at: $$APP_PATH"; \
			open "$$APP_PATH"; \
		else \
			echo "VoiceInk.app not found. Please run 'make build' or 'make local' first."; \
			exit 1; \
		fi; \
	fi

# Cleanup
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(DEPS_DIR)
	@echo "Clean complete"

# Help
help:
	@echo "Available targets:"
	@echo "  check/healthcheck  Check if required CLI tools are installed"
	@echo "  whisper            Clone and build whisper.cpp XCFramework"
	@echo "  setup              Copy whisper XCFramework to VoiceInk project"
	@echo "  build              Build the VoiceInk Xcode project"
	@echo "  local              Build for local use (no Apple Developer certificate needed)"
	@echo "  install-local      Build, reset stale TCC grants, replace /Applications/VoiceInk.app, launch"
	@echo "  setup-signing      Provision a stable self-signed identity (run once for persistent TCC)"
	@echo "  run                Launch the built VoiceInk app"
	@echo "  dev                Build and run the app (for development)"
	@echo "  all                Run full build process (default)"
	@echo "  clean              Remove build artifacts"
	@echo "  help               Show this help message"