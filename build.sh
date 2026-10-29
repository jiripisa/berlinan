#!/bin/bash
# Build script for Berlinan (pipeline adopted from Sampio — development_workflow.md §2)
# Usage: ./build.sh [debug|release|dist|clean]
#
#   debug   — debug build, no optimization (default)
#   release — optimized build + app bundle
#   dist    — release build + Developer ID signing + notarization (app, then DMG) + stapled DMG
#   clean   — remove build artifacts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Berlinan"
BUILD_DIR="$SCRIPT_DIR/build"
SPM_BUILD_DIR="$SCRIPT_DIR/.build"
ICON_SOURCE="Resources/AppIcon.png"
NOTARY_PROFILE="${NOTARY_PROFILE:-notary}"
MODE="${1:-debug}"

# --- Clean ---
if [ "$MODE" == "clean" ]; then
    echo "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    rm -rf "$SPM_BUILD_DIR"
    echo "Clean complete."
    exit 0
fi

# --- Validate mode ---
if [[ "$MODE" != "debug" && "$MODE" != "release" && "$MODE" != "dist" ]]; then
    echo "Unknown mode: $MODE"
    echo "Usage: ./build.sh [debug|release|dist|clean]"
    exit 1
fi

# --- SPM Build ---
if [ "$MODE" == "debug" ]; then
    SPM_CONFIG="debug"
    APP_BUNDLE="$BUILD_DIR/debug/$APP_NAME.app"
    echo "Building $APP_NAME (debug)..."
else
    SPM_CONFIG="release"
    APP_BUNDLE="$BUILD_DIR/release/$APP_NAME.app"
    echo "Building $APP_NAME (release)..."
fi

swift build -c "$SPM_CONFIG"

# --- App Bundle ---
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$SPM_BUILD_DIR/$SPM_CONFIG/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/"

# midi.guide CC catalog for the CC LFO browser (phase 61; CC BY-SA 4.0,
# refreshed by scripts/update_midiguide.py)
cp -R "Resources/MIDIGuide" "$APP_BUNDLE/Contents/Resources/"

# Embed Sparkle (auto-update, phase 56). The app is unsandboxed, so the XPC
# services (only needed by sandboxed apps) are left out.
SPARKLE_SRC=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
SPARKLE_FW="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
ditto "$SPARKLE_SRC" "$SPARKLE_FW"
rm -rf "$SPARKLE_FW/Versions/B/XPCServices" "$SPARKLE_FW/XPCServices"

# Sign Sparkle's pieces inside-out, then the framework (identity "-" = ad-hoc).
sign_sparkle() {
    local identity="$1"; shift
    for item in "$SPARKLE_FW/Versions/B/Autoupdate" \
                "$SPARKLE_FW/Versions/B/Updater.app" \
                "$SPARKLE_FW"; do
        codesign --force "$@" --sign "$identity" "$item" 2>&1 \
            | grep -v "replacing existing signature" || true
    done
}

# Generate .icns from PNG source
if [ -f "$ICON_SOURCE" ]; then
    echo "Generating app icon..."
    ICONSET_DIR=$(mktemp -d)/${APP_NAME}.iconset
    mkdir -p "$ICONSET_DIR"
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null
    iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$(dirname "$ICONSET_DIR")"
else
    echo "WARNING: No AppIcon.png found in Resources/. App will have no icon."
fi

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Strip extended attributes
xattr -cr "$APP_BUNDLE"

# Ad-hoc sign with entitlements for debug/release (TCC needs entitlements
# baked into the binary signature, not just present in the bundle).
sign_sparkle -
codesign --force --sign - \
    --entitlements "Resources/$APP_NAME.entitlements" \
    "$APP_BUNDLE" 2>&1 | grep -v "replacing existing signature" || true

echo "Build complete: $APP_BUNDLE"

# --- Stop here unless dist ---
if [ "$MODE" != "dist" ]; then
    echo "To run: ./run.sh $SPM_CONFIG"
    exit 0
fi

# --- Code Signing ---
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$IDENTITY" ]; then
    echo "ERROR: No 'Developer ID Application' identity found in Keychain; cannot build dist."
    exit 1
fi

echo "Signing with: $IDENTITY"

sign_sparkle "$IDENTITY" --options runtime --timestamp
codesign --force --options runtime --timestamp \
    --entitlements "Resources/$APP_NAME.entitlements" \
    --sign "$IDENTITY" \
    "$APP_BUNDLE"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# --- Notarize and staple the app itself (so the copied app works offline) ---
APP_ZIP="$BUILD_DIR/$APP_NAME-notarize.zip"
rm -f "$APP_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_ZIP"
echo "Submitting $APP_NAME.app for notarization (this may take a few minutes)..."
xcrun notarytool submit "$APP_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$APP_ZIP"
echo "Stapling notarization ticket to $APP_NAME.app..."
xcrun stapler staple "$APP_BUNDLE"

# --- DMG with Applications symlink ---
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"
echo "Creating DMG..."
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_STAGING" \
    -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"

echo "Signing DMG..."
codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"

# --- Notarization ---
echo "Submitting $APP_NAME.dmg for notarization..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "Stapling notarization ticket to the DMG..."
xcrun stapler staple "$DMG_PATH"

# --- Sparkle appcast (auto-update, phase 56) ---
# Signs the final (stapled) DMG with the EdDSA key from the Keychain and
# writes docs/appcast.xml for the GitHub Release that `gh release create`
# publishes as Berlinan-<version>.dmg (same bytes, so length + signature hold).
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
python3 scripts/make_appcast.py "$DMG_PATH" "$VERSION" \
    "https://github.com/jiripisa/berlinan/releases/download/v$VERSION/$APP_NAME-$VERSION.dmg" \
    docs/appcast.xml

echo ""
echo "Done! Signed and notarized DMG: $DMG_PATH"
