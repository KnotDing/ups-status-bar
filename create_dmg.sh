#!/bin/bash

# create_dmg.sh
# This script packages the existing .app bundle into a distributable DMG file.

set -e

APP_NAME="UPSStatusBar.app"
DMG_NAME="UPSStatusBar.dmg"
VOL_NAME="UPSStatusBar Installer"
TEMP_DMG="temp.dmg"

# --- Cleanup old files ---
echo "Cleaning up old files..."
rm -f "$DMG_NAME" "$TEMP_DMG"

# --- Create temporary disk image ---
echo "Creating temporary disk image..."
hdiutil create -size 25m -fs HFS+ -volname "$VOL_NAME" "$TEMP_DMG"

# --- Mount the disk image ---
echo "Mounting disk image..."
# The 'hdiutil attach' command outputs information about the mount point, which we capture.
# The 'tail -n 1' gets the last line, and 'cut -f 3' gets the third field (the mount path).
MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" | tail -n 1 | cut -f 3)
echo "Mounted at $MOUNT_POINT"

# --- Copy app and create symlink ---
echo "Copying .app bundle..."
cp -R "$APP_NAME" "$MOUNT_POINT/"

echo "Creating Applications symlink..."
ln -s /Applications "$MOUNT_POINT/Applications"

# --- Detach the disk image ---
echo "Detaching disk image..."
hdiutil detach "$MOUNT_POINT"

# --- Convert to compressed final image ---
echo "Converting to compressed DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_NAME"

# --- Clean up ---
echo "Cleaning up temporary files..."
rm "$TEMP_DMG"

echo "
DMG created successfully: $DMG_NAME"
