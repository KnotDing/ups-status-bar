#!/bin/bash

# build_app.sh
# This script builds the release executable and packages it into a macOS .app bundle.

set -e # Exit immediately if a command exits with a non-zero status.

APP_NAME="UPSStatusBar.app"
EXECUTABLE_NAME="UPSStatusBar"
BUILD_DIR=".build/release"

echo "Building for release..."
swift build -c release

echo "Creating .app bundle structure..."
rm -rf "$APP_NAME" # Remove old bundle if it exists
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

echo "Copying executable..."
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_NAME/Contents/MacOS/"

echo "Copying Info.plist..."
cp "Info.plist" "$APP_NAME/Contents/"

echo "Copying App Icon..."
cp "UPSStatusBar/Contents/Resources/AppIcon.icns" "$APP_NAME/Contents/Resources/"

echo "Code signing the application (ad-hoc)..."
codesign --force --sign - --deep "$APP_NAME"

echo "Done. You can find $APP_NAME in the project root."
echo "You can now copy $APP_NAME to your /Applications folder."

