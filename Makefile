# Makefile for CleanCopy project

# Configuration (can be overridden: make CONFIG=Release)
CONFIG ?= Debug

APP_NAME=CleanCopy
BUNDLE_ID=interimSolutions.CleanCopy # Ensure this matches your Info.plist PRODUCT_BUNDLE_IDENTIFIER
BUILD_DIR=./build/Build/Products/$(CONFIG) # Build directory depends on CONFIG
APP_PATH=$(BUILD_DIR)/$(APP_NAME).app
DMG_NAME=$(APP_NAME)-$(CONFIG).dmg # DMG name includes CONFIG
RESOURCES_DIR=dmg-resources
BACKGROUND_IMG=$(RESOURCES_DIR)/background.png
LICENSE_FILE=$(RESOURCES_DIR)/LICENSE.txt

# Default target: build the default configuration
all: build

# Build the specified configuration (default: Debug)
build:
	@echo "Building $(APP_NAME) ($(CONFIG))..."
	@xcodebuild -project $(APP_NAME).xcodeproj \
	           -scheme $(APP_NAME) \
	           -configuration $(CONFIG) \
	           -derivedDataPath ./build
	@echo "Build finished. App located in $(BUILD_DIR)/"

# Run the built application (uses default CONFIG unless specified: make run CONFIG=Release)
run: build
	@echo "Running $(APP_NAME) ($(CONFIG))..."
	@open "$(APP_PATH)"

# Package the application into a DMG (uses default CONFIG unless specified: make package CONFIG=Release)
package: build
	@echo "Packaging $(APP_NAME) ($(CONFIG)) into $(DMG_NAME)..."
	@# Ensure resources directory exists (optional, create-dmg might handle it)
	@mkdir -p $(RESOURCES_DIR)
	@# Check if create-dmg exists before running
	@command -v create-dmg >/dev/null 2>&1 || { echo >&2 "Error: create-dmg command not found. Install via Homebrew: brew install create-dmg"; exit 1; }
	@# Check if resource files exist (optional but good practice)
	@[ -f "$(BACKGROUND_IMG)" ] || { echo >&2 "Warning: Background image not found at $(BACKGROUND_IMG)"; }
	@[ -f "$(LICENSE_FILE)" ] || { echo >&2 "Warning: License file not found at $(LICENSE_FILE)"; }
	@# Remove existing DMG if it exists to avoid create-dmg issues
	@rm -f "$(DMG_NAME)"
	@create-dmg \
	  --volname "$(APP_NAME) $(CONFIG)" \
	  --background "$(BACKGROUND_IMG)" \
	  --window-pos 200 120 \
	  --window-size 600 280 \
	  --icon-size 100 \
	  --icon "$(APP_NAME).app" 175 120 \
	  --hide-extension "$(APP_NAME).app" \
	  --app-drop-link 425 120 \
	  --eula "$(LICENSE_FILE)" \
	  "$(DMG_NAME)" \
	  "$(APP_PATH)"
	@echo "DMG created: $(DMG_NAME)"

# Clean the build directory and all generated DMGs
# Note: Does not remove the dmg-resources directory
clean:
	@echo "Cleaning build directory and DMGs..."
	@rm -rf ./build
	@rm -f $(APP_NAME)-*.dmg # Remove all potential DMGs (Debug/Release)
	@echo "Clean complete."

# Reset: Clean build, remove preferences, clear first-launch flags, clear DerivedData, and attempt to remove from /Applications
# WARNING: Removing from /Applications might require sudo if not copied by the current user.
# WARNING: This does NOT automatically unregister the Login Item from System Settings.
reset: clean
	@echo "Resetting application settings, clearing DerivedData, and removing from /Applications..."
	@echo "Attempting to remove preferences file: ~/Library/Preferences/$(BUNDLE_ID).plist"
	@rm -f ~/Library/Preferences/$(BUNDLE_ID).plist
	@echo "Attempting to remove first-launch flags from UserDefaults..."
	@defaults delete $(BUNDLE_ID) moveToApplicationsPromptShown 2>/dev/null || true
	@defaults delete $(BUNDLE_ID) loginItemPromptShownKey 2>/dev/null || true
	@echo "Attempting to remove Xcode DerivedData..."
	@rm -rf ~/Library/Developer/Xcode/DerivedData
	@echo "Attempting to remove application: /Applications/$(APP_NAME).app (may require sudo)"
	@rm -rf "/Applications/$(APP_NAME).app" || echo "  -> Failed to remove /Applications/$(APP_NAME).app (permissions?)"
	@echo "Reset complete. Note: Login Item may need manual removal from System Settings."


# Phony targets are not files
.PHONY: all build run package clean reset