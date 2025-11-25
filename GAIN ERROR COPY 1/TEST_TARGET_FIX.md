# Fix Test Target Warnings

## Issue
The test files (`SessionStoreTests.swift` and `WorkoutStoreTests.swift`) are showing warnings:
- "File 'SessionStoreTests.swift' is part of module 'GAIN'; ignoring import"

This means the test files are in the **GAIN** target when they should only be in the **GAINTests** target.

## Solution

### Option 1: Fix in Xcode (Recommended)

1. **Select the test files** in Project Navigator:
   - `GAINTests/SessionStoreTests.swift`
   - `GAINTests/WorkoutStoreTests.swift`

2. **Open File Inspector** (⌘⌥1 or View > Inspectors > File)

3. **Under "Target Membership"**:
   - ✅ Check **GAINTests** (should be checked)
   - ❌ **Uncheck GAIN** (if it's checked)

4. **Clean and rebuild**:
   - Product > Clean Build Folder (⇧⌘K)
   - Product > Build (⌘B)

### Option 2: Verify Test Target Exists

If GAINTests target doesn't exist:

1. **File > New > Target**
2. Select **iOS > Unit Testing Bundle**
3. Name it **GAINTests**
4. Make sure it's added to the GAIN scheme
5. Move test files to this target

### Option 3: Command Line Check

```bash
# Check which targets the files belong to
xcodebuild -project GAIN.xcodeproj -list
```

## After Fixing

The warnings should disappear and tests will run properly:
- `Cmd + U` to run tests
- Tests will be in the correct target
- `@testable import GAIN` will work correctly

## Verification

After fixing, you should see:
- ✅ No warnings about "part of module 'GAIN'"
- ✅ Tests run successfully
- ✅ `@testable import GAIN` works without warnings



