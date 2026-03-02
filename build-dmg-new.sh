#!/bin/bash

# Near Countdown - macOS DMG Build Script (纯命令行版，尽量避免硬编码路径问题)
set -e

APP_NAME="Near"
ORIGINAL_BINARY_NAME="NearCountdown"          # 必须和 Package.swift 里的 executableTarget 名一致
BUNDLE_IDENTIFIER="com.near.countdown"
BUILD_DIR=".build/release"
DMG_DIR="dist"
VERSION=$(date +%Y%m%d)

echo "🚀 Building Near Countdown for macOS (纯命令行模式)..."

# 0. 可选：清理旧构建，避免残留路径干扰
echo "🧹 Cleaning previous build..."
rm -rf .build/release

# 1. Build release
swift build -c release --disable-sandbox   # --disable-sandbox 有时能避免权限问题

# 2. Create app bundle structure
APP_BUNDLE="$DMG_DIR/$APP_NAME.app"
rm -rf "$DMG_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"

# 3. Copy executable
echo "📦 Copying executable..."
cp "$BUILD_DIR/$ORIGINAL_BINARY_NAME" "$APP_BUNDLE/Contents/MacOS/$ORIGINAL_BINARY_NAME"

# 3.1 Copy any dynamic frameworks (如果有)
echo "📦 Copying Frameworks (if any)..."
find -L "$BUILD_DIR" -name "*.framework" -type d -exec cp -R {} "$APP_BUNDLE/Contents/Frameworks/" \;

# 4. Copy SPM resource bundles (关键：全部拷贝到 Contents/Resources/ 下)
echo "📦 Locating and copying resource bundles..."
RESOURCE_BUNDLES=$(find -L "$BUILD_DIR" -name "*.bundle" -type d)

if [ -n "$RESOURCE_BUNDLES" ]; then
    while IFS= read -r bundlePath; do
        [ -z "$bundlePath" ] && continue
        echo "   Found bundle: $bundlePath"
        cp -R "$bundlePath" "$APP_BUNDLE/Contents/Resources/"
    done <<< "$RESOURCE_BUNDLES"
else
    echo "❌ Error: No .bundle resources found in $BUILD_DIR"
    exit 1
fi

# 4.1 Copy manual Resources folder (如果有额外资源)
if [ -d "Sources/$ORIGINAL_BINARY_NAME/Resources" ] || [ -d "Resources" ]; then
    echo "📦 Copying additional Resources..."
fi

if [ -d "Sources/$ORIGINAL_BINARY_NAME/Resources" ]; then
    cp -R "Sources/$ORIGINAL_BINARY_NAME/Resources/." "$APP_BUNDLE/Contents/Resources/"
fi

if [ -d "Resources" ]; then
    cp -R "Resources/." "$APP_BUNDLE/Contents/Resources/"
fi

if [ ! -d "$APP_BUNDLE/Contents/Resources/icons" ] || [ ! -d "$APP_BUNDLE/Contents/Resources/lottie" ]; then
    echo "❌ Error: Required resources missing (icons/lottie) in app bundle"
    exit 1
fi

# 5. Create Info.plist (添加更多键，让 macOS 更好识别)
echo "📄 Creating Info.plist..."
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
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>   <!-- 如果有图标，放进 Contents/Resources/ -->
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# 6. Fix RPATH for frameworks
echo "🔗 Fixing RPATH..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_BUNDLE/Contents/MacOS/$ORIGINAL_BINARY_NAME" || true

# 7. Clean extended attributes (避免 quarantine)
echo "🧹 Cleaning extended attributes..."
xattr -cr "$APP_BUNDLE"

# 8. Code Signing (更彻底，带 timestamp)
echo "✍️ Signing application..."
# 先签名 frameworks 和 dylibs
find "$APP_BUNDLE/Contents/Frameworks" -name "*.framework" -or -name "*.dylib" | while read -r item; do
    codesign --force --sign - --timestamp "$item" || true
done

# 再深度签名整个 app
codesign --force --deep --sign - --timestamp "$APP_BUNDLE"

# 9. Create DMG
echo "💿 Creating DMG..."
DMG_PATH="$DMG_DIR/$APP_NAME-$VERSION.dmg"
TEMP_DMG_DIR="$DMG_DIR/dmg_temp"
mkdir -p "$TEMP_DMG_DIR"
cp -r "$APP_BUNDLE" "$TEMP_DMG_DIR/"
ln -s /Applications "$TEMP_DMG_DIR/Applications"

hdiutil create -volname "$APP_NAME" -srcfolder "$TEMP_DMG_DIR" -ov -format UDZO "$DMG_PATH"
rm -rf "$TEMP_DMG_DIR"

echo "✅ Done: $DMG_PATH"
echo "   测试方式：双击打开 DMG → 拖到 Applications → 运行 Near.app"
echo "   如果还是崩溃，请确认代码里已改用 ResourceBundle.current 而非 Bundle.module"