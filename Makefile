# Makefile for CleanCopy project

APP_NAME=CleanCopy
BUNDLE_ID=interimSolutions.CleanCopy # Ensure this matches your Info.plist PRODUCT_BUNDLE_IDENTIFIER
BUILD_DIR=./build/Build/Products/Debug
APP_PATH=$(BUILD_DIR)/$(APP_NAME).app
DMG_NAME=$(APP_NAME).dmg
RESOURCES_DIR=dmg-resources
BACKGROUND_IMG=$(RESOURCES_DIR)/background.png
LICENSE_FILE=$(RESOURCES_DIR)/LICENSE.txt

# Default target: build the Debug configuration
all: build

# Build the Debug configuration
build:
	@echo "Building $(APP_NAME) (Debug)..."
	@xcodebuild -project $(APP_NAME).xcodeproj \
	           -scheme $(APP_NAME) \
	           -configuration Debug \
	           -derivedDataPath ./build
	@echo "Build finished. App located in $(BUILD_DIR)/"

# Run the built application
run: build
	@echo "Running $(APP_NAME)..."
	@open "$(APP_PATH)"

# Package the application into a DMG
package: build
	@echo "Packaging $(APP_NAME) into $(DMG_NAME)..."
	@# Ensure resources directory exists (optional, create-dmg might handle it)
	@mkdir -p $(RESOURCES_DIR)
	@# Check if create-dmg exists before running
	@command -v create-dmg >/dev/null 2>&1 || { echo >&2 "Error: create-dmg command not found. Install via Homebrew: brew install create-dmg"; exit 1; }
	@# Check if resource files exist (optional but good practice)
	@[ -f "$(BACKGROUND_IMG)" ] || { echo >&2 "Warning: Background image not found at $(BACKGROUND_IMG)"; }
	@[ -f "$(LICENSE_FILE)" ] || { echo >&2 "Warning: License file not found at $(LICENSE_FILE)"; }
	@create-dmg \
	  --volname "$(APP_NAME)" \
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

# Clean the build directory and DMG
# Note: Does not remove the dmg-resources directory
clean:
	@echo "Cleaning build directory and DMG..."
	@rm -rf ./build
	@rm -f $(DMG_NAME)
	@echo "Clean complete."

# Reset: Clean build, remove preferences, and attempt to remove from /Applications
# WARNING: Removing from /Applications might require sudo if not copied by the current user.
# WARNING: This does NOT automatically unregister the Login Item from System Settings.
reset: clean
	@echo "Resetting application settings and removing from /Applications..."
	@echo "Attempting to remove preferences: ~/Library/Preferences/$(BUNDLE_ID).plist"
	@rm -f ~/Library/Preferences/$(BUNDLE_ID).plist
	@echo "Attempting to remove application: /Applications/$(APP_NAME).app (may require sudo)"
	@rm -rf "/Applications/$(APP_NAME).app" || echo "  -> Failed to remove /Applications/$(APP_NAME).app (permissions?)"
	@echo "Reset complete. Note: Login Item may need manual removal from System Settings."


# Phony targets are not files
.PHONY: all build run package clean reset