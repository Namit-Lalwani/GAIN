# Crash Fix - Initialization Issues

## Problem
The app was crashing on launch because stores were trying to perform async operations during synchronous initialization.

## Root Cause
When `@StateObject` initializes stores like `SessionStore.shared`, `WorkoutStore.shared`, etc., their `init()` methods were immediately starting `Task { @MainActor in ... }` operations. This can cause race conditions and crashes if the app tries to access the stores before the async operations complete.

## Fixes Applied

### 1. ✅ Store Initialization - Changed to DispatchQueue
**Files:** `SessionStore.swift`, `WorkoutStore.swift`, `WeightStore.swift`

**Before:**
```swift
private init() {
    Task { @MainActor in
        await performLoad()
    }
}
```

**After:**
```swift
private init() {
    // Initialize synchronously, load asynchronously after a brief delay
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        Task { @MainActor in
            await self.performLoad()
        }
    }
}
```

**Why:** `DispatchQueue.main.async` ensures the initialization completes synchronously, then the async load happens after the app is ready.

### 2. ✅ GAINApp - Safe Store Access
**File:** `GAINApp.swift`

**Changes:**
- Changed `WeightStore.shared` to `@StateObject private var weightStore` for consistency
- Changed `Task { @MainActor in ... }` to `DispatchQueue.main.async` for iPhoneSessionReceiver initialization

**Why:** Using `@StateObject` for all stores ensures proper lifecycle management, and `DispatchQueue.main.async` is safer for initialization.

## Testing

To verify the fix works:
1. Clean build folder (⇧⌘K)
2. Build and run (⌘R)
3. App should launch without crashing
4. Stores should load data in the background

## If Still Crashing

If the app still crashes, check:
1. **Console logs** - Look for specific error messages
2. **Breakpoints** - Set breakpoints in store `init()` methods
3. **Threading** - Ensure all UI updates are on main thread
4. **File permissions** - Check if file I/O is causing issues

## Additional Safety

All stores now:
- ✅ Initialize synchronously (no blocking)
- ✅ Load data asynchronously (non-blocking)
- ✅ Use weak self in closures (prevent retain cycles)
- ✅ Handle errors gracefully (don't crash on load failures)

