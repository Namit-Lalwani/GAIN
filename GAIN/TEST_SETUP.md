# Test Setup Instructions

The test files (`WorkoutStoreTests.swift` and `SessionStoreTests.swift`) need to be in a separate test target.

## Creating Test Target in Xcode

1. **File > New > Target**
2. Select **iOS > Unit Testing Bundle**
3. Name it `GAINTests`
4. Make sure it's added to the GAIN scheme

## Moving Test Files

1. Select `WorkoutStoreTests.swift` and `SessionStoreTests.swift` in Project Navigator
2. In File Inspector (right panel), change **Target Membership** to:
   - ✅ GAINTests
   - ❌ GAIN (uncheck)

## Alternative: Create Tests Directory Structure

If you prefer command line:

```bash
# Create proper test directory (outside main app)
mkdir -p GAINTests

# Move test files (they'll need to be added to test target in Xcode)
# Or create them directly in the test target
```

## Running Tests

Once properly configured:

```bash
# Run all tests
xcodebuild test \
  -project GAIN.xcodeproj \
  -scheme GAIN \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Or in Xcode: Cmd+U
```

## Test File Location

The test files are currently in `/GAIN/GAINTests/` but they need to be:
- Added to the **GAINTests** target (not GAIN target)
- Accessible via `@testable import GAIN`

## Quick Fix

In Xcode:
1. Select the test files
2. Open File Inspector (⌘⌥1)
3. Under **Target Membership**, ensure only **GAINTests** is checked





