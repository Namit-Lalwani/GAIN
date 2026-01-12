// RecoveryFatigueEngine.swift
import Foundation

public struct WeeklyFatigueMetrics {
    public let weekStart: Date   // start of ISO week
    public let totalVolume: Double
    public let sessionCount: Int
    public let avgSessionScore: Double?   // optional, if you pass sessionScores
    public let fatigueIndex: Double       // 0–100 heuristic
    public let isHighFatigueWeek: Bool
    public let suggestDeload: Bool
}

public enum RecoveryFatigueEngine {
    
    /// Compute weekly fatigue metrics from workouts and optional session scores.
    /// - Parameters:
    ///   - workouts: All workouts.
    ///   - sessionScores: Optional map from workoutId to sessionScore (0–100).
    ///   - highFatigueThreshold: fatigueIndex above which we flag "high fatigue".
    ///   - deloadThreshold: fatigueIndex above which we recommend deload.
    public static func weeklyFatigue(
        workouts: [WorkoutRecord],
        sessionScores: [UUID: Double] = [:],
        highFatigueThreshold: Double = 70,
        deloadThreshold: Double = 85
    ) -> [WeeklyFatigueMetrics] {
        guard !workouts.isEmpty else { return [] }
        
        let calendar = Calendar(identifier: .iso8601)
        
        // Group workouts by week start
        var weeks: [Date: [WorkoutRecord]] = [:]
        for w in workouts {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: w.start)
            guard let weekStart = calendar.date(from: comps) else { continue }
            weeks[weekStart, default: []].append(w)
        }
        
        var result: [WeeklyFatigueMetrics] = []
        
        for (weekStart, ws) in weeks {
            let totalVolume = ws.reduce(0) { $0 + $1.totalVolume }
            let sessionCount = ws.count
            
            let scores: [Double] = ws.compactMap { sessionScores[$0.id] }
            let avgScore: Double? = {
                guard !scores.isEmpty else { return nil }
                let sum = scores.reduce(0, +)
                return sum / Double(scores.count)
            }()
            
            // Simple fatigue index:
            // - Compare this week's volume vs the average of previous 3 weeks.
            // - If we have session scores, blend them in.
            
            let prevWeeks = previousWeeks(
                before: weekStart,
                allWeeks: weeks,
                lookback: 3
            )
            let prevVolumeAvg: Double = {
                guard !prevWeeks.isEmpty else { return 0 }
                let sum = prevWeeks.reduce(0.0) { acc, pair in
                    let (_, wouts) = pair
                    return acc + wouts.reduce(0.0) { $0 + $1.totalVolume }
                }
                let count = prevWeeks.reduce(0) { acc, pair in
                    acc + pair.value.count
                }
                return count > 0 ? sum / Double(count) : 0
            }()
            
            let volumeFactor: Double = {
                guard prevVolumeAvg > 0 else { return 1.0 } // baseline
                return min(max(totalVolume / prevVolumeAvg, 0.0), 2.0) // 0–2
            }()
            
            // Convert volumeFactor [0,2] → [0,100]
            var fatigueIndex = volumeFactor / 2.0 * 100.0
            
            // If we have session scores, incorporate them (lower scores -> more fatigue)
            if let avgScore = avgScore {
                // avgScore 0–100, invert and blend 30% weight
                let inverted = 100.0 - avgScore
                fatigueIndex = 0.7 * fatigueIndex + 0.3 * inverted
            }
            
            let isHigh = fatigueIndex >= highFatigueThreshold
            let deload = fatigueIndex >= deloadThreshold
            
            result.append(
                WeeklyFatigueMetrics(
                    weekStart: weekStart,
                    totalVolume: totalVolume,
                    sessionCount: sessionCount,
                    avgSessionScore: avgScore,
                    fatigueIndex: fatigueIndex,
                    isHighFatigueWeek: isHigh,
                    suggestDeload: deload
                )
            )
        }
        
        // Sort by weekStart
        return result.sorted { $0.weekStart < $1.weekStart }
    }
    
    // MARK: - Helpers
    
    private static func previousWeeks(
        before weekStart: Date,
        allWeeks: [Date: [WorkoutRecord]],
        lookback: Int
    ) -> [(key: Date, value: [WorkoutRecord])] {
        let sortedKeys = allWeeks.keys.sorted()
        guard let idx = sortedKeys.firstIndex(of: weekStart) else { return [] }
        let lower = max(0, idx - lookback)
        let prevKeys = Array(sortedKeys[lower..<idx])
        return prevKeys.map { ($0, allWeeks[$0] ?? []) }
    }
}
