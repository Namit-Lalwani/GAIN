# AI Analytics & Insights Guide

## Overview

The GAIN app now includes comprehensive analytics and AI-powered insights to help you track your fitness progress.

## Features

### 1. Timeline Overview
- **Sessions per day**: Sparkline chart showing workout frequency over last 21 days
- **Volume trends**: Rolling average of workout volume (4-session window)
- Visual indicators for workout consistency

### 2. Personal Records (PRs)
- Automatic detection of new personal records
- Tracks best volume (weight × reps) per exercise
- Highlights recent PRs with trophy icons
- Shows date and exercise for each PR

### 3. Anomaly Detection
- Flags sessions with unusually high or low volume
- Uses statistical z-score analysis (threshold: 2.2)
- Helps identify off-days or exceptional performances

### 4. Exercise Progress Charts
- Per-exercise volume trends
- Rolling average visualization
- Best and average volume statistics
- Session count per exercise

### 5. Session Classification
- Automatically categorizes sessions by intensity:
  - **Low**: < 500 volume
  - **Medium**: 500-2000 volume
  - **High**: > 2000 volume

### 6. AI Summary (Optional)
- Natural language summary of your progress
- Requires backend endpoint (see setup below)
- Can be enabled/disabled via environment variable

## Files Added

1. **`AnalyticsEngine.swift`**
   - Core analytics functions
   - All computations run on-device
   - No external dependencies

2. **`AIInsightsView.swift`**
   - Main insights dashboard
   - Sparkline visualizations
   - PR and anomaly displays
   - Optional AI summary integration

3. **`ExerciseChartView.swift`**
   - Per-exercise detailed charts
   - Progress tracking
   - Volume trends

## Integration

### Accessing AI Insights

**From History Tab:**
- Tap "AI Insights" in the Analytics section
- View comprehensive analytics dashboard

**From Home Tab:**
- Tap the "AI Insights" card
- Quick access to insights

**From Exercise Progress:**
- Navigate to "Exercise Progress" from History
- Select an exercise to see detailed charts

## Configuration

### Enable AI Summary (Optional)

1. **Set Environment Variable:**
```bash
export AI_SUMMARY_ENABLED=true
```

2. **Configure Backend Endpoint:**
   - Update URL in `AIInsightsView.swift`:
   ```swift
   guard let url = URL(string: "https://your-backend.com/api/ai/summary") else {
   ```

3. **Backend Implementation:**
   - Create POST endpoint at `/api/ai/summary`
   - Accept JSON payload with:
     - `totalSessions`: Int
     - `last7`: Int
     - `prsCount`: Int
     - `lastRolling`: Double?
     - `anomalies`: Int
   - Return JSON: `{ "summary": "text summary here" }`

### Example Backend (Node.js/Express)

```javascript
app.post('/api/ai/summary', async (req, res) => {
  const { totalSessions, last7, prsCount, lastRolling, anomalies } = req.body;
  
  // Call your LLM (OpenAI, Anthropic, local, etc.)
  const summary = await generateSummary({
    totalSessions,
    last7,
    prsCount,
    lastRolling,
    anomalies
  });
  
  res.json({ summary });
});
```

## Privacy

- **All analytics run on-device** by default
- No data sent to servers unless AI summary is explicitly enabled
- When enabled, only aggregated statistics are sent (not raw workout data)
- You control what data is shared

## Usage Examples

### Viewing Insights
```swift
// In any view
NavigationLink(destination: AIInsightsView()) {
    Text("View Insights")
}
```

### Accessing Analytics Programmatically
```swift
let stats = AnalyticsEngine.generateSummary(
    workouts: workoutStore.records,
    sessions: sessionStore.sessions
)

let prs = AnalyticsEngine.detectPRs(workouts: workoutStore.records)
let anomalies = AnalyticsEngine.detectVolumeAnomalies(workouts: workoutStore.records)
```

## Analytics Functions

### Sessions Per Day
```swift
let sessionsByDay = AnalyticsEngine.sessionsPerDay(
    sessions: sessionStore.sessions,
    days: 30
)
```

### Rolling Volume Average
```swift
let rolling = AnalyticsEngine.rollingVolume(
    workouts: workoutStore.records,
    window: 4
)
```

### PR Detection
```swift
let prs = AnalyticsEngine.detectPRs(workouts: workoutStore.records)
```

### Anomaly Detection
```swift
let anomalies = AnalyticsEngine.detectVolumeAnomalies(
    workouts: workoutStore.records
)
```

### Session Classification
```swift
let intensity = AnalyticsEngine.classifySessionIntensity(workout)
// Returns: .low, .medium, .high, or .unknown
```

## Visualizations

### Sparklines
- Compact line charts showing trends
- Used for sessions per day and volume trends
- Color-coded (blue for sessions, green for volume)

### Exercise Charts
- Detailed volume progression per exercise
- Rolling average overlay
- Best and average statistics

## Next Steps

1. **Customize Thresholds**: Adjust anomaly detection sensitivity
2. **Add More Metrics**: Extend analytics for specific goals
3. **Backend Integration**: Set up AI summary endpoint
4. **Export Data**: Add CSV/JSON export for analytics
5. **Notifications**: Alert on PRs or anomalies

## Troubleshooting

### No Data Showing
- Ensure you have completed workouts
- Check that workouts have exercises with sets
- Verify data is being saved correctly

### AI Summary Not Working
- Check `AI_SUMMARY_ENABLED` environment variable
- Verify backend endpoint is accessible
- Check network connectivity
- Review backend logs for errors

### Charts Not Rendering
- Ensure iOS 16+ for Charts framework (if using)
- Sparklines work on all iOS versions
- Check data format matches expected structure

## Performance

- All analytics computed on-demand
- Cached results for better performance
- Efficient algorithms for large datasets
- No performance impact on main app





