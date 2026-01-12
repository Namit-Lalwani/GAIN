// SessionQualityEngine.swift
import Foundation

/// Summary metrics for a single workout session,
/// derived from WorkoutRecord + its exercises/sets.
public struct SessionQualityMetrics {
    public let workoutId: UUID
    public let date: Date
    
    /// 0–1: fraction of sets that are marked completed.
    public let completionRate: Double
    
    /// Total volume in this session (sum of reps * weight).
    public let totalVolume: Double
    
    /// Ratio of this session’s volume vs recent average (1.0 = same as avg).
    public let volumeVsRecentAverage: Double
    
    /// A combined 0–100 score for how “good” the session was.
    /// This is a heuristic that can be tuned later.
    public let sessionScore: Double
}

public enum SessionQualityEngine {
    
    /// Compute metrics for a single workout, given recent history
    /// (used for the “recent average” comparison).
    public static func metricsForWorkout(
        _ workout: WorkoutRecord,
        allWorkouts: [WorkoutRecord],
        recentCount: Int = 5
    ) -> SessionQualityMetrics {
        let allSets = workout.exercises.flatMap { $0.sets }
        
        let totalSets = allSets.count
        let completedSets = allSets.filter { $0.isCompleted }.count
        
        let completionRate = totalSets > 0
            ? Double(completedSets) / Double(totalSets)
            : 0.0
        
        let totalVolume = workout.totalVolume
        
        // Recent workouts BEFORE this one (by date)
        let recent = allWorkouts
            .filter { $0.start < workout.start }
            .sorted { $0.start > $1.start }
        
        let recentSlice = Array(recent.prefix(recentCount))
        let recentVolumes = recentSlice.map { $0.totalVolume }
        
        let recentAvgVolume: Double = {
            guard !recentVolumes.isEmpty else { return 0 }
            let sum = recentVolumes.reduce(0, +)
            return sum / Double(recentVolumes.count)
        }()
        
        let volumeVsAvg: Double = {
            guard recentAvgVolume > 0 else { return 1.0 } // treat as baseline
            return totalVolume / recentAvgVolume
        }()
        
        // Heuristic session score:
        // - 60% weight on completion
        // - 40% weight on volume vs avg, capped to [0, 2] then scaled.
        let completionComponent = completionRate                      // 0–1
        let volumeComponent = min(max(volumeVsAvg, 0.0), 2.0) / 2.0   // 0–1
        
        let rawScore = 0.6 * completionComponent + 0.4 * volumeComponent
        let sessionScore = rawScore * 100.0
        
        return SessionQualityMetrics(
            workoutId: workout.id,
            date: workout.start,
            completionRate: completionRate,
            totalVolume: totalVolume,
            volumeVsRecentAverage: volumeVsAvg,
            sessionScore: sessionScore
        )
    }
    
    /// Compute metrics for all workouts, returning them sorted by date.
    public static func metricsForAllWorkouts(
        _ workouts: [WorkoutRecord],
        recentCount: Int = 5
    ) -> [SessionQualityMetrics] {
        let sorted = workouts.sorted { $0.start < $1.start }
        return sorted.map { w in
            metricsForWorkout(w, allWorkouts: sorted, recentCount: recentCount)
        }
    }
}
