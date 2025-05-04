#!/bin/bash
ASSETS_DIR="$SRCROOT/Mend/Assets.xcassets/AppIcon.appiconset"
BUILD_DIR="$TARGET_BUILD_DIR/$PRODUCT_NAME.app"

# Ensure the 120x120 icon is explicitly copied
if [ -f "$ASSETS_DIR/icon-120-fixed.png" ]; then
  cp "$ASSETS_DIR/icon-120-fixed.png" "$BUILD_DIR/AppIcon60x60@2x.png"
fi

# Copy other required icons
if [ -f "$ASSETS_DIR/icon-180.png" ]; then
  cp "$ASSETS_DIR/icon-180.png" "$BUILD_DIR/AppIcon60x60@3x.png"
fi

if [ -f "$ASSETS_DIR/icon-40.png" ]; then
  cp "$ASSETS_DIR/icon-40.png" "$BUILD_DIR/AppIcon20x20@2x.png"
fi

exit 0 