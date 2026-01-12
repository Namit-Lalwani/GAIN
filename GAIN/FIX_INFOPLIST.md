# Fix Info.plist Code Signing Issue

## The Problem
Xcode is complaining that the target doesn't have an Info.plist file configured correctly for code signing.

## Solution Options

### Option 1: Fix in Xcode (Recommended)

1. **Open Xcode** and open `GAIN.xcodeproj`

2. **Select the GAIN target:**
   - Click on the blue project icon in the Project Navigator
   - Select the "GAIN" target (not the project)

3. **Go to Build Settings:**
   - Click on the "Build Settings" tab
   - Make sure "All" and "Combined" are selected at the top

4. **Find Info.plist settings:**
   - Search for "INFOPLIST_FILE" in the search bar
   - Set `INFOPLIST_FILE` to: `GAIN/Info.plist`
   - OR set `GENERATE_INFOPLIST_FILE` to `YES` (if you want Xcode to auto-generate)

5. **Verify the path:**
   - The Info.plist file should be at: `GAIN/GAIN/Info.plist` relative to the project root
   - If the path is wrong, update `INFOPLIST_FILE` to the correct relative path

6. **Clean and rebuild:**
   - Product → Clean Build Folder (Shift+Cmd+K)
   - Product → Build (Cmd+B)

### Option 2: Use Auto-Generated Info.plist (Modern Approach)

1. In Build Settings, set:
   - `GENERATE_INFOPLIST_FILE` = `YES`
   - `INFOPLIST_FILE` = (leave empty or remove)

2. Move the custom keys (like NSHealthShareUsageDescription) to the target's Info tab:
   - Select the target
   - Go to "Info" tab
   - Add custom keys there

### Option 3: Verify File Location

The Info.plist file exists at: `/Users/nileshlalwani/Documents/GAIN/GAIN/GAIN/Info.plist`

Make sure the build setting `INFOPLIST_FILE` points to the correct relative path from the project root.

## Current Build Setting
The current setting shows: `INFOPLIST_FILE = GAIN/Info.plist`

This might need to be: `INFOPLIST_FILE = GAIN/GAIN/Info.plist` depending on your project structure.

