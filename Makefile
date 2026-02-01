# Configuration
VERSION ?= 1.0.0
BUILD_NUMBER ?= $(shell git rev-list --count HEAD)
BUNDLE_NAME = JuliaSetCamera.app
BUILD_DIR = .build/arm64-apple-macosx/release
APP_DIR = $(BUILD_DIR)/$(BUNDLE_NAME)

metallib:
	mkdir -p .build
	xcrun metal -fcikernel -c Sources/JuliaKit/Filters/JuliaWarp.ci.metal \
		-o .build/JuliaWarp.air
	xcrun metallib --cikernel .build/JuliaWarp.air \
		-o Sources/JuliaKit/Filters/JuliaWarp.ci.metallib
	xcrun metal -fcikernel -c Sources/JuliaKit/Filters/ChromaticAberration.ci.metal \
		-o .build/ChromaticAberration.air
	xcrun metallib --cikernel .build/ChromaticAberration.air \
		-o Sources/JuliaKit/Filters/ChromaticAberration.ci.metallib

app: clean-app
	@echo "Building Julia Set Camera.app..."
	@echo "Version: $(VERSION) (build $(BUILD_NUMBER))"

	# Build release binary
	swift build -c release

	# Create app bundle structure
	mkdir -p $(APP_DIR)/Contents/MacOS
	mkdir -p $(APP_DIR)/Contents/Resources

	# Copy executable
	cp $(BUILD_DIR)/CameraDemo $(APP_DIR)/Contents/MacOS/

	# Copy resource bundle (Metal shaders)
	cp -R $(BUILD_DIR)/CameraDemo_JuliaKit.bundle $(APP_DIR)/Contents/Resources/

	# Generate Info.plist with version substitution
	sed -e 's/__VERSION__/$(VERSION)/g' \
	    -e 's/__BUILD_NUMBER__/$(BUILD_NUMBER)/g' \
	    Info.plist > $(APP_DIR)/Contents/Info.plist

	# Create PkgInfo
	echo -n "APPL????" > $(APP_DIR)/Contents/PkgInfo

	# Ad-hoc code sign
	codesign --force --deep --sign - $(APP_DIR)

	@echo "✅ App bundle created at: $(APP_DIR)"
	@echo "   Launch with: open $(APP_DIR)"

install: app
	@echo "Installing to /Applications..."
	cp -R $(APP_DIR) /Applications/
	@echo "✅ Installed to /Applications/$(BUNDLE_NAME)"

clean-app:
	rm -rf $(APP_DIR)

.PHONY: metallib app install clean-app
