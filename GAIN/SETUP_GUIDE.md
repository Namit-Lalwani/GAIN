# GAIN App Setup Guide

This guide covers setting up the GAIN fitness app with persistence, testing, and Apple Watch support.

## Table of Contents
1. [Persistence Configuration](#persistence-configuration)
2. [Running Tests](#running-tests)
3. [Apple Watch Setup](#apple-watch-setup)
4. [Environment Variables](#environment-variables)
5. [Git Commands](#git-commands)
6. [Next Steps](#next-steps)

## Persistence Configuration

The app uses **local persistence by default**. To enable Supabase cloud sync, set environment variables.

### Option 1: Environment Variables (Recommended for Development)

Set these in your Xcode scheme or terminal:

```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_KEY=your-anon-key
```

### Option 2: Info.plist (For Production)

Add these keys to your `Info.plist`:

```xml
<key>SUPABASE_URL</key>
<string>https://your-project.supabase.co</string>
<key>SUPABASE_KEY</key>
<string>your-anon-key</string>
```

**⚠️ Security Note**: Never commit service-role keys to version control. Use environment injection in CI/CD.

### How It Works

The app automatically detects Supabase credentials and switches from local to cloud persistence:

```swift
// In PersistenceConfig.swift
public static var currentType: PersistenceType {
    if let _ = ProcessInfo.processInfo.environment["SUPABASE_URL"],
       let _ = ProcessInfo.processInfo.environment["SUPABASE_KEY"] {
        return .supabase
    }
    return .local
}
```

## Running Tests

### Prerequisites

Tests use XCTest (built into Xcode).

### Run Tests in Xcode

1. Open the project in Xcode
2. Press `Cmd + U` or go to **Product > Test**
3. Or run specific tests from the Test Navigator (⌘6)

### Run Tests from Command Line

```bash
# Build and run all tests
xcodebuild test \
  -project GAIN.xcodeproj \
  -scheme GAIN \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run specific test suite
xcodebuild test \
  -project GAIN.xcodeproj \
  -scheme GAIN \
  -only-testing:GAINTests/SessionStoreTests \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Test Coverage

Current test suites:
- **WorkoutStoreTests**: Tests for workout CRUD operations
- **SessionStoreTests**: Tests for session lifecycle and metrics

## Apple Watch Setup

### 1. Add WatchKit Extension Target

1. In Xcode: **File > New > Target**
2. Select **watchOS > App**
3. Name it "GAIN Watch App"
4. Add `WatchSessionManager.swift` to the Watch target

### 2. Configure WatchConnectivity

Add to both iOS and Watch targets:

**Info.plist (iOS)**:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
```

**Info.plist (Watch)**:
```xml
<key>WKBackgroundModes</key>
<array>
    <string>workout-processing</string>
</array>
```

### 3. Initialize on iOS Side

In `GAINApp.swift`:

```swift
@main
struct GAINApp: App {
    init() {
        // Initialize Watch connectivity
        _ = iPhoneSessionReceiver.shared
    }
    
    var body: some Scene {
        // ...
    }
}
```

### 4. Initialize on Watch Side

In your Watch app's main view:

```swift
import WatchKit

@main
struct GAINWatchApp: App {
    init() {
        _ = WatchSessionManager.shared
        WatchSessionManager.shared.requestHealthKitAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 5. HealthKit Permissions

Add to both targets' `Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>GAIN needs access to heart rate and workout data for live metrics.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>GAIN needs to write workout data to Health for accurate tracking.</string>
```

## Environment Variables

### Development

Create a `.env` file (not committed):

```bash
SUPABASE_URL=https://xyzcompany.supabase.co
SUPABASE_KEY=your-anon-key-here
```

Load in Xcode scheme:
1. **Product > Scheme > Edit Scheme**
2. **Run > Arguments > Environment Variables**
3. Add `SUPABASE_URL` and `SUPABASE_KEY`

### Production

Use:
- **Xcode Cloud**: Environment variables in workflow
- **Fastlane**: `.env` file (not in repo)
- **CI/CD**: Secure environment injection

## Git Commands

### Initial Setup

```bash
# Initialize repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "GAIN: Swift implementation with session management, metrics, and Watch support"

# Create patch file
git format-patch -1 HEAD
# Creates: 0001-GAIN-Swift-implementation.patch
```

### Development Workflow

```bash
# Check status
git status

# Add changes
git add .

# Commit
git commit -m "Description of changes"

# Create patch
git format-patch -1 HEAD
```

## Supabase Database Setup

### 1. Create Table

Run in Supabase SQL Editor:

```sql
create table user_state (
  id text primary key,
  state jsonb,
  updated_at timestamptz default now()
);

-- Add index for faster queries
create index idx_user_state_updated_at on user_state(updated_at);
```

### 2. Row Level Security (RLS)

For multi-user support:

```sql
-- Enable RLS
alter table user_state enable row level security;

-- Policy: users can only access their own state
create policy "Users can access own state"
  on user_state
  for all
  using (auth.uid()::text = id);
```

### 3. Update Adapter

In `SupabasePersistenceAdapter`, replace `'local_user'` with actual user ID when auth is implemented.

## Next Steps

### ✅ Completed
- [x] Session management with status tracking
- [x] Metrics logging (heart rate, power, cadence)
- [x] Local persistence
- [x] Conflict resolution with revision numbers
- [x] Unit tests for core functionality
- [x] WatchConnectivity skeleton
- [x] Switchable persistence (local/Supabase)

### 🔄 In Progress / TODO
- [ ] Complete Supabase adapter implementation
- [ ] HealthKit integration for real-time metrics
- [ ] Backend API endpoint (`/api/sessions/ingest`)
- [ ] Watch app UI implementation
- [ ] Offline queue for failed syncs
- [ ] User authentication
- [ ] Multi-user support

### 📝 Notes

**What I Cannot Run:**
- Supabase connection (requires real keys)
- App Store signing (requires Apple Developer account)
- Physical device testing (requires signed provisioning)
- Watch app testing (requires Watch device or simulator)

**Where to Paste Secrets:**
1. **Development**: Xcode scheme environment variables
2. **CI/CD**: Secure environment variables in your CI platform
3. **Production**: Keychain or secure configuration service

**Conflict Resolution:**
- Uses revision numbers (incremented on each update)
- Higher revision wins
- For equal revisions: ended sessions win over active
- Device ID helps with tie-breaking

**For Production:**
- Consider CRDTs or vector clocks for complex merges
- Implement proper error handling and retry logic
- Add analytics for sync failures
- Monitor sync performance

## Troubleshooting

### Tests Not Running
- Ensure test target is added to scheme
- Check that `@testable import GAIN` works
- Verify test files are in the test target

### Watch Not Connecting
- Ensure both iOS and Watch apps are running
- Check WCSession activation state
- Verify WatchConnectivity is supported on device

### Supabase Not Working
- Verify environment variables are set
- Check network connectivity
- Review Supabase dashboard for errors
- Ensure table schema matches

## Support

For issues or questions:
1. Check logs in Xcode console
2. Review error messages
3. Verify configuration matches this guide





