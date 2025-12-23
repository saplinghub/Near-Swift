#!/bin/bash

# Near Countdown - macOS DMG Build Script
# Builds a release version and packages it into a DMG file

set -e

APP_NAME="Near"
BUNDLE_IDENTIFIER="com.near.countdown"
BUILD_DIR=".build/release"
DMG_DIR="dist"
VERSION=$(date +%Y%m%d)

echo "🚀 Building Near Countdown for macOS..."

# 1. Build release
echo "📦 Building release..."
swift build -c release

# 2. Create app bundle structure
echo "📁 Creating app bundle..."
APP_BUNDLE="$DMG_DIR/$APP_NAME.app"
rm -rf "$DMG_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy executable
cp "$BUILD_DIR/NearCountdown" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 4. Copy resources
if [ -d "Resources" ]; then
    cp -r Resources/* "$APP_BUNDLE/Contents/Resources/"
fi

# 5. Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_IDENTIFIER</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# 6. Create DMG
echo "💿 Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$DMG_DIR/$DMG_NAME"

# Create temporary DMG directory
TEMP_DMG_DIR="$DMG_DIR/dmg_temp"
mkdir -p "$TEMP_DMG_DIR"
cp -r "$APP_BUNDLE" "$TEMP_DMG_DIR/"

# Create symbolic link to Applications folder
ln -s /Applications "$TEMP_DMG_DIR/Applications"

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$TEMP_DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# Cleanup
rm -rf "$TEMP_DMG_DIR"

echo ""
echo "✅ Build complete!"
echo "📦 App Bundle: $APP_BUNDLE"
echo "💿 DMG: $DMG_PATH"
echo ""
echo "To install: Open the DMG and drag Near to Applications folder."
