// StrengthAnalytics.swift
import Foundation

/// Algorithms to estimate one-rep max (1RM)
enum OneRepMaxAlgorithm {
    case epley
    case brzycki
    
    func estimate1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        
        switch self {
        case .epley:
            // 1RM = w * (1 + reps / 30)
            return weight * (1.0 + Double(reps) / 30.0)
            
        case .brzycki:
            // 1RM = w * 36 / (37 - reps)
            let denom = 37.0 - Double(reps)
            guard denom > 0 else { return 0 }
            return weight * 36.0 / denom
        }
    }
}

/// A summarized performance data point for a single exercise in a single workout.
struct ExercisePerformanceSample: Identifiable {
    let id = UUID()
    let date: Date
    let exerciseName: String
    let bestSetWeight: Double
    let bestSetReps: Int
    let estimated1RM: Double
    let totalVolume: Double
    let totalReps: Int
}

struct StrengthAnalytics {
    
    /// Extract per-exercise performance samples from a list of workouts.
    /// - Parameters:
    ///   - workouts: All workout records.
    ///   - exerciseName: Optional filter; if nil, returns samples for all exercises.
    ///   - algorithm: Algorithm for 1RM estimation.
    static func exerciseSamples(
        from workouts: [WorkoutRecord],
        exerciseName: String? = nil,
        algorithm: OneRepMaxAlgorithm = .epley
    ) -> [ExercisePerformanceSample] {
        var result: [ExercisePerformanceSample] = []
        
        for workout in workouts {
            for exercise in workout.exercises {
                if let filter = exerciseName, exercise.name != filter {
                    continue
                }
                
                // Find "best" set for this exercise in this workout
                // We’ll use highest estimated 1RM as the criterion.
                var bestSet: WorkoutSetRecord?
                var bestSet1RM: Double = 0
                
                var totalVolume: Double = 0
                var totalReps: Int = 0
                
                for set in exercise.sets {
                    let setVolume = Double(set.reps) * set.weight
                    totalVolume += setVolume
                    totalReps += set.reps
                    
                    let oneRM = algorithm.estimate1RM(weight: set.weight, reps: set.reps)
                    if oneRM > bestSet1RM {
                        bestSet1RM = oneRM
                        bestSet = set
                    }
                }
                
                guard let best = bestSet else { continue }
                
                let sample = ExercisePerformanceSample(
                    date: workout.start,
                    exerciseName: exercise.name,
                    bestSetWeight: best.weight,
                    bestSetReps: best.reps,
                    estimated1RM: bestSet1RM,
                    totalVolume: totalVolume,
                    totalReps: totalReps
                )
                
                result.append(sample)
            }
        }
        
        // Sort by date ascending so it’s easy to use in charts later.
        return result.sorted { $0.date < $1.date }
    }
    
    /// Get 1RM history for a single exercise across all workouts.
    static func oneRMHistory(
        for exerciseName: String,
        workouts: [WorkoutRecord],
        algorithm: OneRepMaxAlgorithm = .epley
    ) -> [(date: Date, oneRM: Double)] {
        let samples = exerciseSamples(
            from: workouts,
            exerciseName: exerciseName,
            algorithm: algorithm
        )
        
        return samples.map { (date: $0.date, oneRM: $0.estimated1RM) }
    }
    
    /// Get the best (max) estimated 1RM for an exercise.
    static func bestOneRM(
        for exerciseName: String,
        workouts: [WorkoutRecord],
        algorithm: OneRepMaxAlgorithm = .epley
    ) -> Double {
        oneRMHistory(for: exerciseName, workouts: workouts, algorithm: algorithm)
            .map { $0.oneRM }
            .max() ?? 0
    }
}
