.PHONY: run build restart clean generate

APP_NAME = Throw
BUILD_DIR = $(HOME)/Library/Developer/Xcode/DerivedData/ThrowMac-*/Build/Products/Debug
APP_PATH = $(shell ls -d $(BUILD_DIR)/$(APP_NAME).app 2>/dev/null | head -1)

# Build and run
run: build restart

# Build only
build:
	@xcodebuild -project ThrowMac.xcodeproj -scheme ThrowMac -configuration Debug build 2>&1 | grep -E "(error:|BUILD)" || true

# Kill and restart app
restart:
	@pkill -f "$(APP_NAME)" 2>/dev/null || true
	@sleep 0.5
	@open "$(APP_PATH)"
	@echo "✓ $(APP_NAME) restarted"

# Kill app
kill:
	@pkill -f "$(APP_NAME)" 2>/dev/null || true
	@echo "✓ $(APP_NAME) killed"

# Regenerate Xcode project
generate:
	@xcodegen generate

# Clean build
clean:
	@xcodebuild clean -project ThrowMac.xcodeproj -scheme ThrowMac 2>/dev/null || true
	@echo "✓ Cleaned"

# Full rebuild
rebuild: clean generate build restart
