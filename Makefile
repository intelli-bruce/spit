# Drops MonoRepo Makefile

DEVICE_ID = 00008150-000D15D02288401C

# iOS App
IOS_DIR = ios
IOS_BUNDLE_ID = com.intellieffect.drops
IOS_SCHEME = Drops
IOS_PROJECT = $(IOS_DIR)/Drops.xcodeproj
IOS_BUILD_DIR = $(HOME)/Library/Developer/Xcode/DerivedData/Drops-*/Build/Products/Debug-iphoneos
IOS_APP_PATH = $(IOS_BUILD_DIR)/Drops.app

# Mac App
MAC_DIR = mac
MAC_SCHEME = JournalMac
MAC_PROJECT = $(MAC_DIR)/JournalMac.xcodeproj

.PHONY: ios-generate ios-build ios-install ios-run ios-device ios-simulator ios-clean ios-open
.PHONY: mac-generate mac-build mac-run mac-clean mac-open
.PHONY: clean help

# ============================================
# iOS App Commands
# ============================================

ios-generate:
	cd $(IOS_DIR) && xcodegen generate

ios-build: ios-generate
	xcodebuild -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) \
		-destination 'id=$(DEVICE_ID)' \
		-allowProvisioningUpdates build

ios-simulator: ios-generate
	xcodebuild -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

ios-install:
	xcrun devicectl device install app --device $(DEVICE_ID) $(IOS_APP_PATH)

ios-run:
	xcrun devicectl device process launch --device $(DEVICE_ID) $(IOS_BUNDLE_ID)

ios-device: ios-build ios-install ios-run

ios-clean:
	xcodebuild -project $(IOS_PROJECT) -scheme $(IOS_SCHEME) clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Drops-*

ios-open:
	open $(IOS_PROJECT)

# ============================================
# Mac App Commands
# ============================================

mac-generate:
	cd $(MAC_DIR) && xcodegen generate

mac-build: mac-generate
	xcodebuild -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) build

mac-run: mac-build
	open $(MAC_DIR)/build/Debug/JournalMac.app

mac-clean:
	xcodebuild -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/JournalMac-*

mac-open:
	open $(MAC_PROJECT)

# ============================================
# Common Commands
# ============================================

clean: ios-clean mac-clean

help:
	@echo "Drops MonoRepo Build Commands"
	@echo ""
	@echo "iOS App:"
	@echo "  make ios-device    - Build, install, and run on connected iPhone"
	@echo "  make ios-build     - Build for connected device"
	@echo "  make ios-simulator - Build for iOS Simulator"
	@echo "  make ios-generate  - Generate Xcode project"
	@echo "  make ios-clean     - Clean build artifacts"
	@echo "  make ios-open      - Open in Xcode"
	@echo ""
	@echo "Mac App:"
	@echo "  make mac-build     - Build Mac app"
	@echo "  make mac-run       - Build and run Mac app"
	@echo "  make mac-generate  - Generate Xcode project"
	@echo "  make mac-clean     - Clean build artifacts"
	@echo "  make mac-open      - Open in Xcode"
	@echo ""
	@echo "Common:"
	@echo "  make clean         - Clean all build artifacts"
