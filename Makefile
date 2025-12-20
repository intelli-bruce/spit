# Throw MonoRepo Makefile

.PHONY: help
.PHONY: ios ios-build ios-sim ios-generate ios-clean ios-open
.PHONY: mac mac-build mac-restart mac-kill mac-generate mac-clean mac-open mac-rebuild

# ============================================
# Configuration
# ============================================

DEVICE_ID = 00008150-000D15D02288401C

# iOS
IOS_DIR = ios
IOS_PROJECT = $(IOS_DIR)/Throw.xcodeproj
IOS_SCHEME = Throw
IOS_BUNDLE_ID = com.intellieffect.throw
IOS_BUILD_DIR = $(HOME)/Library/Developer/Xcode/DerivedData/Throw-*/Build/Products/Debug-iphoneos
IOS_APP_PATH = $(IOS_BUILD_DIR)/Throw.app

# Mac
MAC_DIR = mac
MAC_PROJECT = $(MAC_DIR)/ThrowMac.xcodeproj
MAC_SCHEME = ThrowMac
MAC_BUILD_DIR = $(HOME)/Library/Developer/Xcode/DerivedData/ThrowMac-*/Build/Products/Debug
MAC_APP_PATH = $(shell ls -d $(MAC_BUILD_DIR)/Throw.app 2>/dev/null | head -1)

# ============================================
# iOS Commands
# ============================================

ios: ios-build ios-install ios-run  ## Build, install, run on device

ios-build: ios-generate  ## Build for device
	@xcodebuild -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) \
		-destination 'id=$(DEVICE_ID)' \
		-allowProvisioningUpdates build 2>&1 | grep -E "(error:|BUILD)" || true

ios-sim: ios-generate  ## Build for simulator
	@xcodebuild -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "(error:|BUILD)" || true

ios-install:  ## Install on device
	@xcrun devicectl device install app --device $(DEVICE_ID) $(IOS_APP_PATH)

ios-run:  ## Launch on device
	@xcrun devicectl device process launch --device $(DEVICE_ID) $(IOS_BUNDLE_ID)

ios-generate:  ## Generate Xcode project
	@cd $(IOS_DIR) && xcodegen generate

ios-clean:  ## Clean build
	@xcodebuild -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) clean 2>/dev/null || true
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Throw-*
	@echo "✓ iOS cleaned"

ios-open:  ## Open in Xcode
	@open $(IOS_PROJECT)

# ============================================
# Mac Commands
# ============================================

mac: mac-build mac-restart  ## Build and restart app

mac-build:  ## Build app
	@xcodebuild -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Debug build 2>&1 | grep -E "(error:|BUILD)" || true

mac-restart:  ## Kill and restart app
	@pkill -f "Throw" 2>/dev/null || true
	@sleep 0.5
	@open "$(MAC_APP_PATH)"
	@echo "✓ Throw restarted"

mac-kill:  ## Kill app
	@pkill -f "Throw" 2>/dev/null || true
	@echo "✓ Throw killed"

mac-generate:  ## Generate Xcode project
	@cd $(MAC_DIR) && xcodegen generate

mac-clean:  ## Clean build
	@xcodebuild -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) clean 2>/dev/null || true
	@rm -rf ~/Library/Developer/Xcode/DerivedData/ThrowMac-*
	@echo "✓ Mac cleaned"

mac-open:  ## Open in Xcode
	@open $(MAC_PROJECT)

mac-rebuild: mac-clean mac-generate mac-build mac-restart  ## Full rebuild

# ============================================
# Common
# ============================================

clean: ios-clean mac-clean  ## Clean all

help:  ## Show this help
	@echo "Throw MonoRepo Build Commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
