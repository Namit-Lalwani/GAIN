# Session Management & Sync Features

This document describes the new session management, metrics logging, and sync capabilities added to the GAIN app.

## New Files Added

### 1. `SessionModels.swift`
Contains the core models for session management:
- **`SessionStatus`**: Enum for session states (running, paused, ended)
- **`Metric`**: Structure for logging workout metrics (heart rate, power, cadence, etc.)
- **`WorkoutSession`**: Complete session model with:
  - Status tracking
  - Metrics collection
  - Revision numbers for conflict resolution
  - Device ID tracking
  - Duration calculation

### 2. `SessionStore.swift`
Observable store for managing workout sessions:
- **Session Lifecycle**: Start, pause, resume, end sessions
- **Metrics Logging**: Log heart rate, power, cadence, and custom metrics
- **Persistence**: Automatic save/load of sessions
- **Conflict Resolution**: Merge logic for syncing with remote data
- **Active Session Tracking**: Track currently active session

### 3. `SyncAdapter.swift`
Infrastructure for data synchronization:
- **`PersistenceAdapter` Protocol**: Pluggable persistence layer
- **`LocalPersistenceAdapter`**: Local file-based storage
- **`SupabasePersistenceAdapter`**: Stub for future cloud sync
- **`AppState`**: Unified app state structure
- **Conflict Resolution**: Merge logic for handling sync conflicts

## Key Features

### Session Management
```swift
let sessionStore = SessionStore.shared

// Start a new session
let session = sessionStore.startSession(workoutId: workoutId)

// Pause/Resume
sessionStore.pauseSession(session.id)
sessionStore.resumeSession(session.id)

// End session
sessionStore.endSession(session.id, finalMetrics: ["duration": AnyCodable(3600)])
```

### Metrics Logging
```swift
// Log metrics during workout
sessionStore.logMetric(
    sessionId: session.id,
    heartRate: 150,
    power: 250,
    cadence: 90,
    secondsElapsed: 120
)
```

### Conflict Resolution
- Uses revision numbers to determine which version wins
- Higher revision number takes precedence
- For equal revisions: ended sessions win over active ones
- Device ID tracking for multi-device scenarios

## Integration

The `SessionStore` has been added to `GAINApp.swift` and is available as an environment object throughout the app:

```swift
@EnvironmentObject var sessionStore: SessionStore
```

## Future Enhancements

1. **Supabase Integration**: Complete the `SupabasePersistenceAdapter` implementation
2. **HealthKit Integration**: Connect metrics logging to HealthKit
3. **Apple Watch Support**: Sync sessions from Watch companion app
4. **Real-time Sync**: Background sync with conflict resolution
5. **Offline Queue**: Queue sync operations when offline

## Usage Example

```swift
struct WorkoutSessionView: View {
    @EnvironmentObject var sessionStore: SessionStore
    
    var body: some View {
        VStack {
            if let activeSession = sessionStore.activeSession {
                Text("Session: \(activeSession.duration) seconds")
                Button("Log Heart Rate") {
                    sessionStore.logMetric(
                        sessionId: activeSession.id,
                        heartRate: 150
                    )
                }
            } else {
                Button("Start Session") {
                    sessionStore.startSession()
                }
            }
        }
    }
}
```

## Notes

- All sessions are automatically persisted to disk
- Active sessions are restored on app launch if they weren't ended
- Revision numbers increment on each update for conflict resolution
- Device IDs help identify the source of data in multi-device scenarios





