#!/bin/bash
# Run this from your homeease project root
# Fixes the Android v1 embedding error

echo "Fixing Android build..."

# Remove old Java plugin registrant if it exists
if [ -f "android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java" ]; then
  rm android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
  echo "Removed old GeneratedPluginRegistrant.java"
fi

# Remove old java directory if empty
rmdir android/app/src/main/java/io/flutter/plugins 2>/dev/null
rmdir android/app/src/main/java/io/flutter 2>/dev/null
rmdir android/app/src/main/java/io 2>/dev/null
rmdir android/app/src/main/java 2>/dev/null

echo "Done! Now run: flutter clean && flutter run"
