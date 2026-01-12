import SwiftUI

/// Aggregates advanced analytics in one place so the main workout UI stays clean.
struct AdvancedAnalyticsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var sessionStore: SessionStore
    
    // Precomputed metrics
    private var weeklyAdherence: [WeeklyAdherenceSummary] {
    AdherenceEngine.weeklySummary(
        workouts: workoutStore.records,
        weeksBack: 8,
        targetPerWeek: 3    // adjust this default if you like
    )
}
    private var adherenceSummary: AdherenceSummary {
    AdherenceEngine.summary(workouts: workoutStore.records, days: 30)
}
    private var sessionMetrics: [SessionQualityMetrics] {
        SessionQualityEngine.metricsForAllWorkouts(workoutStore.records)
    }
    
    private var weeklyFatigue: [WeeklyFatigueMetrics] {
        let scoreMap = Dictionary(uniqueKeysWithValues: sessionMetrics.map { ($0.workoutId, $0.sessionScore) })
        return RecoveryFatigueEngine.weeklyFatigue(
            workouts: workoutStore.records,
            sessionScores: scoreMap
        )
    }
    
    private var weeklyMuscle: [WeeklyMuscleBalance] {
        MuscleGroupAnalytics.weeklyMuscleBalance(workouts: workoutStore.records)
    }
    
    var body: some View {
        List {
            // Session quality summary
            Section("Session Quality") {
                if sessionMetrics.isEmpty {
                    Text("No workouts yet").foregroundColor(.secondary)
                } else if let latest = sessionMetrics.last {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest session score: \(Int(latest.sessionScore)) / 100")
                            .font(.headline)
                        Text("Completion: \(Int(latest.completionRate * 100))%")
                            .font(.subheadline)
                        Text(String(format: "Volume vs recent: %.1fx", latest.volumeVsRecentAverage))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            // Habits & Streaks
Section("Habits & Streaks (last 30 days)") {
    let summary = adherenceSummary
    
    if summary.totalDays == 0 {
        Text("No data yet").foregroundColor(.secondary)
    } else {
        VStack(alignment: .leading, spacing: 6) {
            Text("Consistency: \(Int(summary.consistencyScore))%")
                .font(.headline)
            Text("Current streak: \(summary.currentStreak) days")
            Text("Longest streak: \(summary.longestStreak) days")
            Text("Workouts on \(summary.daysWithWorkout) of \(summary.totalDays) days")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}
// Weekly Targets
Section("Weekly Targets (last 8 weeks)") {
    if weeklyAdherence.isEmpty {
        Text("No weekly data yet").foregroundColor(.secondary)
    } else {
        ForEach(weeklyAdherence) { week in
            VStack(alignment: .leading, spacing: 4) {
                Text(week.weekStart, style: .date)
                    .font(.headline)
                Text("Workout days: \(week.workoutsDone) / \(week.targetWorkouts)")
                Text("Total sessions: \(week.totalSessions)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if week.metTarget {
                    Text("Target met ✅")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Text("Below target")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
    }
}
            // Fatigue / deload suggestions
            Section("Recovery & Fatigue") {
                if weeklyFatigue.isEmpty {
                    Text("No weekly data yet").foregroundColor(.secondary)
                } else {
                    ForEach(weeklyFatigue, id: \.weekStart) { week in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(week.weekStart, style: .date)
                                .font(.headline)
                            Text(String(format: "Fatigue index: %.0f", week.fatigueIndex))
                            if week.suggestDeload {
                                Text("Deload recommended")
                                    .foregroundColor(.red)
                            } else if week.isHighFatigueWeek {
                                Text("High fatigue week")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            
            // Muscle balance
            Section("Muscle Balance (weekly)") {
                if weeklyMuscle.isEmpty {
                    Text("No tagged muscle data yet").foregroundColor(.secondary)
                } else {
                    ForEach(weeklyMuscle, id: \.weekStart) { week in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(week.weekStart, style: .date)
                                .font(.headline)
                            Text(String(format: "Push: %.0f  Pull: %.0f  Legs: %.0f",
                                        week.pushVolume, week.pullVolume, week.legsVolume))
                                .font(.subheadline)
                        }
                    }
                }
            }
            
            // Example: one simple strength summary using StrengthAnalytics
            Section("Strength (example)") {
                // Find a common exercise name if any
                let names = Set(workoutStore.records.flatMap { $0.exercises.map { $0.name } })
                if let sampleName = names.sorted().first {
                    let best = StrengthAnalytics.bestOneRM(for: sampleName, workouts: workoutStore.records)
                    Text("Best est. 1RM for \(sampleName): \(Int(best)) kg")
                } else {
                    Text("No exercises logged yet").foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Advanced Analytics")
    }
}

#Preview {
    NavigationStack {
        AdvancedAnalyticsView()
            .environmentObject(WorkoutStore.preview)
            .environmentObject(SessionStore.shared)
    }
}
