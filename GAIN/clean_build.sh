#!/bin/bash

# Clean build script for GAIN iOS app
# This removes derived data and cleans the build

echo "🧹 Cleaning GAIN project..."

# Get the project directory
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData"

# Find and remove GAIN derived data
echo "Removing Derived Data..."
find "$BUILD_DIR" -name "GAIN-*" -type d -exec rm -rf {} + 2>/dev/null

echo "✅ Clean complete!"
echo ""
echo "Next steps:"
echo "1. Open GAIN.xcodeproj in Xcode"
echo "2. Remove the 'GAIN Watch Watch App' target (see FIX_WATCH_ISSUE.md)"
echo "3. Remove the 'GAIN Watch Watch App' scheme"
echo "4. Select the 'GAIN' scheme (iOS app)"
echo "5. Build and run (Cmd+R)"



