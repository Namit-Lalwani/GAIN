# Troubleshooting Guide

## Quick Fixes for Common Issues

### App Crashes on Launch
**Check:**
1. All environment objects are injected in `GAINApp.swift`
2. No force unwraps on nil values
3. Stores are properly initialized

**Fix:**
- Verify `SessionStore.shared` is initialized
- Check that all `@EnvironmentObject` properties have providers

### AI Insights Shows "No data yet"
**This is normal if:**
- You haven't completed any workouts yet
- Workouts don't have exercises with sets

**To fix:**
1. Go to Templates tab
2. Create a template with exercises
3. Start a workout from Workout tab
4. Add sets with weight and reps
5. Complete the workout
6. Return to AI Insights

### Exercise Progress Shows "No exercises found"
**This is normal if:**
- No workouts have been completed
- Workouts don't have exercises

**To fix:**
- Complete at least one workout with exercises

### Charts Not Rendering
**Check:**
1. Data exists (workouts with exercises and sets)
2. Sets have weight and reps values
3. Workouts are properly saved

**Fix:**
- Ensure sets have non-zero weight and reps
- Verify workouts are being saved to WorkoutStore

### Navigation Not Working
**Check:**
1. Views are wrapped in NavigationView or NavigationStack
2. NavigationLinks are properly configured
3. Destination views exist

**Fix:**
- HistoryView uses NavigationView
- AIInsightsView and ExerciseProgressView are accessible via NavigationLink

### Sparklines Show Empty
**This is normal if:**
- Less than 2 data points (need multiple sessions for trend)
- All values are zero

**Fix:**
- Complete multiple workouts to see trends
- Ensure workouts have volume (weight × reps > 0)

## Testing Steps

### 1. Create Test Data
```swift
// In ContentView, use the demo buttons:
// "Add Demo Workout" - creates sample workout
// "Add Demo Weight" - creates sample weight entry
```

### 2. Verify Data Flow
1. Check WorkoutStore has records: `workoutStore.records.count > 0`
2. Check exercises exist: `workoutStore.records.flatMap { $0.exercises }.count > 0`
3. Check sets exist: `workoutStore.records.flatMap { $0.exercises.flatMap { $0.sets } }.count > 0`

### 3. Test Analytics
1. Complete 3-5 workouts with same exercise
2. Navigate to Exercise Progress
3. Select the exercise
4. Should see volume trend chart

## Debug Tips

### Check Console Logs
Look for:
- "WorkoutStore save error" - persistence issues
- "SessionStore load error" - data loading issues
- Network errors - if AI summary is enabled

### Verify Store State
Add temporary debug views:
```swift
Text("Workouts: \(workoutStore.records.count)")
Text("Sessions: \(sessionStore.sessions.count)")
```

### Test Individual Functions
```swift
let stats = AnalyticsEngine.generateSummary(
    workouts: workoutStore.records,
    sessions: sessionStore.sessions
)
print("Stats: \(stats)")
```

## Common Error Messages

### "Cannot find type 'WorkoutSession'"
- Ensure SessionModels.swift is included in target
- Check imports are correct

### "Value of optional type 'Optional<...>' must be unwrapped"
- Add nil checks before using optional values
- Use `if let` or `guard let` for safe unwrapping

### "Index out of range"
- Check arrays before accessing by index
- Use safe array access: `array.indices.contains(index)`

## Performance Issues

### Slow Loading
- Analytics are computed on-demand
- Large datasets may take a moment
- Consider caching results for better performance

### Memory Issues
- Sessions and workouts are stored in memory
- Consider pagination for large datasets
- Clear old data periodically

## Still Not Working?

1. **Clean Build:**
   ```bash
   xcodebuild clean
   ```

2. **Reset Simulator:**
   - Device > Erase All Content and Settings

3. **Check Logs:**
   - View > Debug Area > Show Debug Area (⌘⇧Y)
   - Look for error messages

4. **Verify Files:**
   - All new files are added to target
   - No duplicate file names
   - Imports are correct

All fixes have been applied. The app should work correctly now! 🚀




