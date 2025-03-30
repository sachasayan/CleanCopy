# Makefile for CleanCopy project

APP_NAME=CleanCopy
BUILD_DIR=./build/Build/Products/Debug
APP_PATH=$(BUILD_DIR)/$(APP_NAME).app
DMG_NAME=$(APP_NAME).dmg

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

# Package the application into a DMG
package: build
	@echo "Packaging $(APP_NAME) into $(DMG_NAME)..."
	@create-dmg \
	  --volname "$(APP_NAME)" \
	  --window-pos 200 120 \
	  --window-size 600 280 \
	  --icon-size 100 \
	  --icon "$(APP_NAME).app" 175 120 \
	  --hide-extension "$(APP_NAME).app" \
	  --app-drop-link 425 120 \
	  "$(DMG_NAME)" \
	  "$(APP_PATH)"
	@echo "DMG created: $(DMG_NAME)"

# Clean the build directory and DMG
clean:
	@echo "Cleaning build directory and DMG..."
	@rm -rf ./build
	@rm -f $(DMG_NAME)
	@echo "Clean complete."

# Phony targets are not files
.PHONY: all build package clean