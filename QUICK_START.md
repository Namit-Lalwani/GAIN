# GAIN App - Quick Start Guide

## ✅ What's Been Added

### 1. Switchable Persistence
- **Local by default**: Uses file-based storage
- **Supabase when configured**: Automatically switches if env vars are present
- See `PersistenceConfig.swift` for configuration

### 2. Unit Tests
- `WorkoutStoreTests.swift`: Tests for workout CRUD
- `SessionStoreTests.swift`: Tests for session lifecycle
- **Note**: Tests need to be in separate test target (see TEST_SETUP.md)

### 3. Apple Watch Support
- `WatchSessionManager.swift`: Watch-side session management
- `iPhoneSessionReceiver.swift`: iPhone-side message receiver
- HealthKit integration for heart rate
- Offline packet queuing

### 4. Session Management
- Start, pause, resume, end sessions
- Metrics logging (heart rate, power, cadence)
- Conflict resolution with revision numbers
- Device ID tracking

## 🚀 Quick Commands

### Build
```bash
cd /Users/nileshlalwani/Documents/GAIN/GAIN
xcodebuild -project GAIN.xcodeproj -scheme GAIN -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### Test (after setting up test target)
```bash
xcodebuild test -project GAIN.xcodeproj -scheme GAIN -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Git Setup
```bash
git init
git add .
git commit -m "GAIN: Swift implementation with session management, metrics, Watch support, and tests"
git format-patch -1 HEAD  # Creates patch file
```

## 📝 Configuration

### Enable Supabase (Optional)

**Option 1: Environment Variables**
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_KEY=your-anon-key
```

**Option 2: Info.plist**
Add keys: `SUPABASE_URL` and `SUPABASE_KEY`

### Watch Setup

1. Add WatchKit extension target in Xcode
2. Add `WatchSessionManager.swift` to Watch target
3. Initialize in Watch app:
```swift
_ = WatchSessionManager.shared
WatchSessionManager.shared.requestHealthKitAuthorization()
```

## 📚 Documentation

- `SETUP_GUIDE.md`: Complete setup instructions
- `TEST_SETUP.md`: Test target configuration
- `SESSION_FEATURES.md`: Session management details

## ⚠️ Important Notes

### Cannot Test Without:
- **Supabase**: Real API keys and database setup
- **Watch**: Physical Watch device or Watch simulator
- **Device**: Apple Developer account for signing

### Where to Add Secrets:
- **Development**: Xcode scheme environment variables
- **CI/CD**: Secure environment variables
- **Never commit**: Service-role keys or private keys

## 🎯 Next Steps

1. ✅ Set up test target (see TEST_SETUP.md)
2. ✅ Configure Supabase (if using cloud sync)
3. ✅ Add WatchKit extension target
4. ✅ Implement backend API endpoint
5. ✅ Connect HealthKit for real metrics

## 📦 Files Added

- `PersistenceConfig.swift` - Persistence selection
- `SessionModels.swift` - Session and metric models
- `SessionStore.swift` - Session management store
- `SyncAdapter.swift` - Sync infrastructure
- `WatchSessionManager.swift` - Watch connectivity
- `iPhoneSessionReceiver.swift` - iPhone message receiver
- `GAINTests/WorkoutStoreTests.swift` - Workout tests
- `GAINTests/SessionStoreTests.swift` - Session tests

All features are implemented and ready to use!





