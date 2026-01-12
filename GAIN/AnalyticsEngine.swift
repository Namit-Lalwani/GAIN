import Foundation

// Note: This file depends on WorkoutRecord (from WorkoutRecord.swift) 
// and WorkoutSession (from SessionModels.swift)

// MARK: - Analytics Engine
// Lightweight analytics helpers for GAIN
// All functions are deterministic and run on-device

public struct AnalyticsEngine {
    
    // MARK: - Sessions Per Day
    /// Returns sessions per day for the last N days
    public static func sessionsPerDay(
        sessions: [WorkoutSession],
        days: Int = 30
    ) -> [(date: String, count: Int)] {
        let now = Date()
        let calendar = Calendar.current
        var result: [(date: String, count: Int)] = []
        
        // Create date range
        for i in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -i, to: now) else { continue }
            let dateKey = ISO8601DateFormatter().string(from: date).prefix(10)
            result.append((date: String(dateKey), count: 0))
        }
        
        // Count sessions per day
        var dayMap: [String: Int] = [:]
        for entry in result {
            dayMap[entry.date] = 0
        }
        
        for session in sessions {
            let dayKey = ISO8601DateFormatter().string(from: session.startedAt).prefix(10)
            if dayMap[String(dayKey)] != nil {
                dayMap[String(dayKey)] = (dayMap[String(dayKey)] ?? 0) + 1
            }
        }
        
        return result.map { (date: $0.date, count: dayMap[$0.date] ?? 0) }
    }
    
    // MARK: - Session Volume
    /// Compute volume per session (weight * reps)
    public static func computeSessionVolume(_ session: WorkoutSession) -> Double {
        // Try to get volume from finalMetrics
        if let volume = session.finalMetrics?["volume"]?.value as? Double {
            return volume
        }
        
        // Calculate from metrics if available
        // This is a simplified calculation - in real app, you'd have structured set data
        return 0.0 // Placeholder - would need access to workout record sets
    }
    
    /// Compute volume from workout record
    public static func computeWorkoutVolume(_ workout: WorkoutRecord) -> Double {
        return workout.totalVolume
    }
    
    // MARK: - Rolling Average
    /// Rolling moving average of session volumes
    public static func rollingVolume(
        workouts: [WorkoutRecord],
        window: Int = 4
    ) -> [(id: UUID, date: Date, volume: Double, movingAverage: Double)] {
        let sorted = workouts.sorted { $0.start < $1.start }
        var result: [(id: UUID, date: Date, volume: Double, movingAverage: Double)] = []
        
        for i in 0..<sorted.count {
            let slice = Array(sorted[max(0, i - window + 1)...i])
            let avg = slice.isEmpty ? 0.0 : slice.reduce(0.0) { $0 + computeWorkoutVolume($1) } / Double(slice.count)
            result.append((
                id: sorted[i].id,
                date: sorted[i].start,
                volume: computeWorkoutVolume(sorted[i]),
                movingAverage: avg
            ))
        }
        
        return result
    }
    
    // MARK: - PR Detection
    public struct PR: Identifiable {
        public let id: UUID
        public let sessionId: UUID
        public let exerciseId: String?
        public let type: PRType
        public let value: Double
        public let date: Date
        
        public enum PRType: String {
            case weight
            case volume
            case reps
        }
    }
    
    /// Detect personal records per exercise
    public static func detectPRs(workouts: [WorkoutRecord]) -> [PR] {
        var prs: [PR] = []
        var bestByExercise: [String: Double] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                let exerciseId = exercise.name
                
                for set in exercise.sets {
                    let metric = set.weight * Double(set.reps)
                    let currentBest = bestByExercise[exerciseId]
                    
                    if currentBest == nil || metric > (currentBest ?? 0) {
                        bestByExercise[exerciseId] = metric
                        prs.append(PR(
                            id: UUID(),
                            sessionId: workout.id,
                            exerciseId: exerciseId,
                            type: .volume,
                            value: metric,
                            date: workout.start
                        ))
                    }
                }
            }
        }
        
        return prs.sorted { $0.date > $1.date }
    }

    /// Best (max) PR per exercise across all workouts.
    /// Uses the PR value from detectPRs (currently volume-based) and keeps the latest PR for each exercise.
    public static func bestPRPerExercise(workouts: [WorkoutRecord]) -> [(exercise: String, value: Double, date: Date)] {
        let prs = detectPRs(workouts: workouts)
        var best: [String: (value: Double, date: Date)] = [:]

        for pr in prs {
            guard let exercise = pr.exerciseId else { continue }
            let current = best[exercise]
            if current == nil || pr.value > (current?.value ?? 0) {
                best[exercise] = (value: pr.value, date: pr.date)
            }
        }

        return best
            .map { (exercise: $0.key, value: $0.value.value, date: $0.value.date) }
            .sorted { $0.value > $1.value }
    }
    
    // MARK: - Muscle Group Volume
    /// Aggregate volume and set counts per muscle group based on WorkoutExerciseRecord.muscleGroups.
    /// If an exercise has multiple groups, its volume is counted towards each group.
    public static func volumeByMuscleGroup(workouts: [WorkoutRecord]) -> [(group: String, volume: Double, sets: Int)] {
        var aggregates: [String: (volume: Double, sets: Int)] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                let groups = (exercise.muscleGroups ?? ["Other"]).isEmpty ? ["Other"] : (exercise.muscleGroups ?? ["Other"])
                let exerciseVolume = exercise.sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
                let exerciseSets = exercise.sets.count
                guard exerciseVolume > 0 || exerciseSets > 0 else { continue }
                
                for group in groups {
                    let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
                    let key = trimmed.isEmpty ? "Other" : trimmed
                    let current = aggregates[key] ?? (0.0, 0)
                    aggregates[key] = (
                        volume: current.volume + exerciseVolume,
                        sets: current.sets + exerciseSets
                    )
                }
            }
        }
        
        return aggregates
            .map { (group: $0.key, volume: $0.value.volume, sets: $0.value.sets) }
            .sorted { $0.volume > $1.volume }
    }
    
    // MARK: - Heart Rate Zones
    public struct HRZones {
        public let zone1: TimeInterval // < 60% max
        public let zone2: TimeInterval // 60-75%
        public let zone3: TimeInterval // 75-85%
        public let zone4: TimeInterval // > 85%
        
        public var total: TimeInterval {
            zone1 + zone2 + zone3 + zone4
        }
    }
    
    /// Calculate heart rate zones for a session
    public static func hrZonesForSession(
        _ session: WorkoutSession,
        hrMax: Double = 190
    ) -> HRZones? {
        let samples = session.metrics.compactMap { $0.heartRate }
        guard !samples.isEmpty else { return nil }
        
        var zones = HRZones(zone1: 0, zone2: 0, zone3: 0, zone4: 0)
        
        for i in 0..<(samples.count - 1) {
            let hr = samples[i]
            let percentage = hr / hrMax
            let duration: TimeInterval = 1.0 // Approximate 1 second per sample
            
            if percentage < 0.6 {
                zones = HRZones(
                    zone1: zones.zone1 + duration,
                    zone2: zones.zone2,
                    zone3: zones.zone3,
                    zone4: zones.zone4
                )
            } else if percentage < 0.75 {
                zones = HRZones(
                    zone1: zones.zone1,
                    zone2: zones.zone2 + duration,
                    zone3: zones.zone3,
                    zone4: zones.zone4
                )
            } else if percentage < 0.85 {
                zones = HRZones(
                    zone1: zones.zone1,
                    zone2: zones.zone2,
                    zone3: zones.zone3 + duration,
                    zone4: zones.zone4
                )
            } else {
                zones = HRZones(
                    zone1: zones.zone1,
                    zone2: zones.zone2,
                    zone3: zones.zone3,
                    zone4: zones.zone4 + duration
                )
            }
        }
        
        return zones
    }
    
    // MARK: - Anomaly Detection
    /// Detect volume anomalies using z-score
    public static func detectVolumeAnomalies(workouts: [WorkoutRecord]) -> [UUID] {
        let volumes = workouts.map { computeWorkoutVolume($0) }
        guard !volumes.isEmpty else { return [] }
        
        let mean = volumes.reduce(0.0, +) / Double(volumes.count)
        let variance = volumes.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(volumes.count)
        let std = sqrt(variance)
        guard std > 0 else { return [] }
        
        var anomalies: [UUID] = []
        
        for workout in workouts {
            let volume = computeWorkoutVolume(workout)
            let zScore = abs((volume - mean) / std)
            if zScore > 2.2 {
                anomalies.append(workout.id)
            }
        }
        
        return anomalies
    }
    
    // MARK: - Session Classification
    public enum SessionIntensity: String {
        case low
        case medium
        case high
        case unknown
    }
    
    /// Classify session intensity based on volume
    public static func classifySessionIntensity(_ workout: WorkoutRecord) -> SessionIntensity {
        let volume = computeWorkoutVolume(workout)
        
        if volume == 0 {
            return .unknown
        } else if volume < 500 {
            return .low
        } else if volume < 2000 {
            return .medium
        } else {
            return .high
        }
    }
    
    /// Count sessions per intensity bucket for a collection of workouts.
    public static func intensityBreakdown(workouts: [WorkoutRecord]) -> [(intensity: SessionIntensity, count: Int)] {
        var counts: [SessionIntensity: Int] = [:]
        
        for workout in workouts {
            let category = classifySessionIntensity(workout)
            guard category != .unknown else { continue }
            counts[category, default: 0] += 1
        }
        
        return counts
            .map { (intensity: $0.key, count: $0.value) }
            .sorted { $0.intensity.rawValue < $1.intensity.rawValue }
    }
    
    // MARK: - Summary Statistics
    public struct SummaryStats {
        public let totalSessions: Int
        public let last7DaysSessions: Int
        public let totalPRs: Int
        public let recentPRs: [PR]
        public let anomalies: Int
        public let averageVolume: Double
        public let lastRollingAverage: Double?
    }
    
    /// Generate summary statistics
    public static func generateSummary(
        workouts: [WorkoutRecord],
        sessions: [WorkoutSession]
    ) -> SummaryStats {
        let sessionsByDay = sessionsPerDay(sessions: sessions, days: 7)
        let last7 = sessionsByDay.reduce(0) { $0 + $1.count }
        let prs = detectPRs(workouts: workouts)
        let anomalies = detectVolumeAnomalies(workouts: workouts)
        let volumes = workouts.map { computeWorkoutVolume($0) }
        let avgVolume = volumes.isEmpty ? 0.0 : volumes.reduce(0.0, +) / Double(volumes.count)
        let rolling = rollingVolume(workouts: workouts, window: 4)
        let lastRolling = rolling.last?.movingAverage
        
        return SummaryStats(
            totalSessions: workouts.count,
            last7DaysSessions: last7,
            totalPRs: prs.count,
            recentPRs: Array(prs.prefix(3)),
            anomalies: anomalies.count,
            averageVolume: avgVolume,
            lastRollingAverage: lastRolling
        )
    }
}

