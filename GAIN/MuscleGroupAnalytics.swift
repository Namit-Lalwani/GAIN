// MuscleGroupAnalytics.swift
import Foundation

public struct MuscleGroupVolume {
    public let muscleGroup: String
    public let totalVolume: Double
    public let sessionCount: Int
}

public struct WeeklyMuscleBalance {
    public let weekStart: Date
    public let volumes: [MuscleGroupVolume]
    
    /// Simple push/pull/legs comparison if tags follow those groups.
    public let pushVolume: Double
    public let pullVolume: Double
    public let legsVolume: Double
}

public enum MuscleGroupAnalytics {
    
    /// Compute weekly muscle-group volume.
    /// Assumes `muscleGroups` on exercises contain normalized strings like
    /// "chest", "back", "legs", "push", "pull", etc.
    public static func weeklyMuscleBalance(
        workouts: [WorkoutRecord]
    ) -> [WeeklyMuscleBalance] {
        guard !workouts.isEmpty else { return [] }
        
        let calendar = Calendar(identifier: .iso8601)
        var weeks: [Date: [WorkoutRecord]] = [:]
        
        for w in workouts {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: w.start)
            guard let weekStart = calendar.date(from: comps) else { continue }
            weeks[weekStart, default: []].append(w)
        }
        
        var result: [WeeklyMuscleBalance] = []
        
        for (weekStart, ws) in weeks {
            var volumeByGroup: [String: (volume: Double, sessions: Set<UUID>)] = [:]
            
            for workout in ws {
                for ex in workout.exercises {
                    guard let tags = ex.muscleGroups, !tags.isEmpty else { continue }
                    let exVolume = ex.totalVolume
                    
                    for tag in tags {
                        let key = tag.lowercased()
                        var entry = volumeByGroup[key] ?? (0.0, [])
                        entry.volume += exVolume
                        entry.sessions.insert(workout.id)
                        volumeByGroup[key] = entry
                    }
                }
            }
            
            let volumes: [MuscleGroupVolume] = volumeByGroup.map { key, value in
                MuscleGroupVolume(
                    muscleGroup: key,
                    totalVolume: value.volume,
                    sessionCount: value.sessions.count
                )
            }
            
            // Derive push/pull/legs from tags if present.
            func sum(forGroups groups: [String]) -> Double {
                let set = Set(groups.map { $0.lowercased() })
                return volumes
                    .filter { set.contains($0.muscleGroup) }
                    .reduce(0) { $0 + $1.totalVolume }
            }
            
            let push = sum(forGroups: ["push", "chest", "shoulders", "triceps"])
            let pull = sum(forGroups: ["pull", "back", "biceps"])
            let legs = sum(forGroups: ["legs", "quads", "hamstrings", "glutes"])
            
            result.append(
                WeeklyMuscleBalance(
                    weekStart: weekStart,
                    volumes: volumes,
                    pushVolume: push,
                    pullVolume: pull,
                    legsVolume: legs
                )
            )
        }
        
        return result.sorted { $0.weekStart < $1.weekStart }
    }
}
