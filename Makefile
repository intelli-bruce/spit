# Drops iOS App Makefile

DEVICE_ID = 00008150-000D15D02288401C
BUNDLE_ID = com.intellieffect.drops
SCHEME = Drops
PROJECT = Drops.xcodeproj
BUILD_DIR = $(HOME)/Library/Developer/Xcode/DerivedData/Drops-*/Build/Products/Debug-iphoneos
APP_PATH = $(BUILD_DIR)/Drops.app

.PHONY: generate build install run device simulator clean open

# Generate Xcode project from project.yml
generate:
	xcodegen generate

# Build for connected device
build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'id=$(DEVICE_ID)' \
		-allowProvisioningUpdates build

# Build for simulator
simulator: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Install app on device
install:
	xcrun devicectl device install app --device $(DEVICE_ID) $(APP_PATH)

# Launch app on device
run:
	xcrun devicectl device process launch --device $(DEVICE_ID) $(BUNDLE_ID)

# Build, install, and run on device
device: build install run

# Clean build artifacts
clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf ~/Library/Developer/Xcode/DerivedData/Drops-*

# Open in Xcode
open:
	open $(PROJECT)

# Show help
help:
	@echo "Drops iOS App Build Commands"
	@echo ""
	@echo "  make device     - Build, install, and run on connected iPhone"
	@echo "  make build      - Build for connected device"
	@echo "  make simulator  - Build for iOS Simulator"
	@echo "  make install    - Install app on device"
	@echo "  make run        - Launch app on device"
	@echo "  make generate   - Generate Xcode project"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make open       - Open in Xcode"
