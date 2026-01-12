# Fix Watch Target Issue in Xcode

The Xcode project still has a watch target that needs to be removed. Follow these steps:

## Steps to Remove Watch Target:

1. **Open the project in Xcode:**
   - Open `GAIN.xcodeproj` in Xcode

2. **Remove the Watch Target:**
   - In the Project Navigator (left sidebar), click on the project name "GAIN" (blue icon at the top)
   - In the main editor, you'll see "TARGETS" section
   - Find any target with "Watch" in the name (e.g., "GAIN Watch Watch App")
   - Select it and press the Delete key, or right-click and select "Delete"
   - When prompted, choose "Move to Trash" (not "Remove Reference")

3. **Remove the Watch Scheme:**
   - At the top of Xcode, click on the scheme selector (next to the play/stop buttons)
   - Click "Manage Schemes..."
   - Find "GAIN Watch Watch App" scheme
   - Uncheck it or select it and click the "-" button to delete it
   - Click "Close"

4. **Clean Build Folder:**
   - Go to Product → Clean Build Folder (or press Shift+Cmd+K)
   - Wait for it to complete

5. **Delete Derived Data (if needed):**
   - Go to Xcode → Settings → Locations
   - Click the arrow next to "Derived Data" path
   - Find the "GAIN-..." folder and delete it
   - Close the Finder window

6. **Verify Build Settings:**
   - Select the "GAIN" target (iOS app target)
   - Go to Build Settings tab
   - Search for "Supported Platforms"
   - Make sure it shows: `iphoneos iphonesimulator` (NOT watchos)
   - Search for "Base SDK"
   - Make sure it shows: `Latest iOS` (NOT watchOS)

7. **Rebuild the Project:**
   - Close Xcode completely
   - Reopen the project
   - Select the "GAIN" scheme (iOS app, not watch)
   - Select an iOS simulator (iPhone 15, iPhone 16, etc.)
   - Build and run (Cmd+R)

## If You Still See Issues:

- Make sure you're selecting the correct scheme: "GAIN" (not "GAIN Watch Watch App")
- Make sure you're building for iOS Simulator, not watchOS Simulator
- Try deleting the entire Derived Data folder for a fresh build



