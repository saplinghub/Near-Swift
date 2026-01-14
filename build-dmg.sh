#!/bin/bash

# Near Countdown - macOS DMG Build Script
set -e

APP_NAME="Near"
# 重要：保持原始 Target 名称，这是 SPM 查找资源的唯一线索
ORIGINAL_BINARY_NAME="NearCountdown"
BUNDLE_IDENTIFIER="com.near.countdown"
BUILD_DIR=".build/release"
DMG_DIR="dist"
VERSION=$(date +%Y%m%d)

echo "🚀 Building Near Countdown for macOS..."

# 1. Build release
swift build -c release

# 2. Create app bundle structure
APP_BUNDLE="$DMG_DIR/$APP_NAME.app"
rm -rf "$DMG_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# 3. Copy executable
cp "$BUILD_DIR/$ORIGINAL_BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/"

# 3.1 Copy Frameworks
echo "📦 Copying Frameworks..."
find -L .build/release -name "*.framework" -type d -exec cp -R {} "$APP_BUNDLE/Contents/Frameworks/" \;

# 4. Copy resources
if [ -d "Resources" ]; then
    cp -r Resources/* "$APP_BUNDLE/Contents/Resources/"
fi

# 4.1 Copy SwiftPM Resources Bundle
BUNDLE_PATH=$(find -L .build/release -name "*.bundle" -type d | head -n 1)
if [ -n "$BUNDLE_PATH" ]; then
    echo "📦 Copying resources bundle: $BUNDLE_PATH"
    cp -r "$BUNDLE_PATH" "$APP_BUNDLE/Contents/Resources/"
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
    <key>CFBundleExecutable</key>
    <string>$ORIGINAL_BINARY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 5.1 Fix RPATH
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$ORIGINAL_BINARY_NAME" || true

# 5.2 Clean Extended Attributes
echo "🧹 Cleaning extended attributes..."
xattr -cr "$APP_BUNDLE"

# 5.3 Code Signing (SIMPLIFIED)
echo "✍️  Signing application..."
# 1. 彻底移除所有现有签名
find "$APP_BUNDLE" -name "_CodeSignature" -type d -exec rm -rf {} + 2>/dev/null || true

# 2. 先签名 Frameworks
if [ -d "$APP_BUNDLE/Contents/Frameworks" ]; then
    find "$APP_BUNDLE/Contents/Frameworks" -name "*.framework" -or -name "*.dylib" | while read -r item; do
        codesign --force --sign - --timestamp=none "$item"
    done
fi

# 3. 对整个 App 进行深度签名（跳过对 bundle 文件夹的单独签名，它会由 --deep 处理）
echo "Final bundle signing..."
codesign --force --sign - --deep "$APP_BUNDLE"

# 6. Create DMG
echo "💿 Creating DMG..."
DMG_PATH="$DMG_DIR/$APP_NAME-$VERSION.dmg"
TEMP_DMG_DIR="$DMG_DIR/dmg_temp"
mkdir -p "$TEMP_DMG_DIR"
cp -r "$APP_BUNDLE" "$TEMP_DMG_DIR/"
ln -s /Applications "$TEMP_DMG_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$TEMP_DMG_DIR"

echo "✅ Done: $DMG_PATH"
