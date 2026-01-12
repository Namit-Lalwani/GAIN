// ProgressiveOverloadEngine.swift
import Foundation

/// Basic progression strategy for an exercise.
public struct ProgressionParameters {
    /// How many recent sessions to look at (e.g. last 3–5 workouts with this exercise).
    public var recentSessions: Int
    
    /// Target reps per set. We try to keep this band.
    public var targetRepsPerSet: ClosedRange<Int>
    
    /// Step size for weight progression (kg).
    public var weightIncrement: Double

    public var minIncrementKg: Double?

    public var maxIncrementKg: Double?

    public var mostRecentSessionWeight: Double

    public var recencyDecayFactor: Double

    public var backoffPercentRange: ClosedRange<Double>

    public var deloadPercentRange: ClosedRange<Double>

    public var stallLookbackSessions: Int
    
    /// Maximum recommended sets per session for this exercise.
    public var maxSets: Int
    
    public init(
        recentSessions: Int = 5,
        targetRepsPerSet: ClosedRange<Int> = 6...12,
        weightIncrement: Double = 2.5,
        maxSets: Int = 4,
        minIncrementKg: Double? = nil,
        maxIncrementKg: Double? = nil,
        mostRecentSessionWeight: Double = 0.4,
        recencyDecayFactor: Double = 0.6,
        backoffPercentRange: ClosedRange<Double> = 0.82...0.90,
        deloadPercentRange: ClosedRange<Double> = 0.15...0.20,
        stallLookbackSessions: Int = 4
    ) {
        self.recentSessions = recentSessions
        self.targetRepsPerSet = targetRepsPerSet
        self.weightIncrement = weightIncrement
        self.maxSets = maxSets
        self.minIncrementKg = minIncrementKg
        self.maxIncrementKg = maxIncrementKg
        self.mostRecentSessionWeight = mostRecentSessionWeight
        self.recencyDecayFactor = recencyDecayFactor
        self.backoffPercentRange = backoffPercentRange
        self.deloadPercentRange = deloadPercentRange
        self.stallLookbackSessions = stallLookbackSessions
    }
}

/// A single planned set for the next session.
public struct PlannedSet {
    public let reps: Int
    public let weight: Double
}

/// A suggested plan for the next session of a specific exercise.
public struct ExercisePlan {
    public let exerciseName: String
    public let plannedSets: [PlannedSet]
    public let notes: String
}

public enum ProgressiveOverloadEngine {
    
    /// Suggest a plan for the next session of a given exercise.
    ///
    /// This is intentionally conservative and simple:
    /// - Looks at the last N sessions of that exercise.
    /// - Determines a typical working weight and reps band.
    /// - If reps are consistently at the top of the band, nudges weight up.
    /// - If reps are low, keeps or slightly reduces weight.
    public static func planNextSession(
        for exerciseName: String,
        from workouts: [WorkoutRecord],
        params: ProgressionParameters = ProgressionParameters()
    ) -> ExercisePlan? {
        let relevantWorkouts = workouts
            .sorted { $0.start > $1.start }
            .filter { record in
                record.exercises.contains(where: { $0.name == exerciseName })
            }
        
        guard !relevantWorkouts.isEmpty else {
            // No history: suggest a simple beginner plan
            let defaultSets = (0..<3).map { _ in
                PlannedSet(reps: params.targetRepsPerSet.lowerBound, weight: 20.0)
            }
            return ExercisePlan(
                exerciseName: exerciseName,
                plannedSets: defaultSets,
                notes: "No history found. Starting with light beginner sets."
            )
        }
        
        let recent = Array(relevantWorkouts.prefix(params.recentSessions))

        let sessions: [(workout: WorkoutRecord, exercise: WorkoutExerciseRecord)] = recent.compactMap { workout in
            guard let ex = workout.exercises.first(where: { $0.name == exerciseName }) else { return nil }
            return (workout, ex)
        }

        guard !sessions.isEmpty else {
            return nil
        }

        let lower = Double(params.targetRepsPerSet.lowerBound)
        let upper = Double(params.targetRepsPerSet.upperBound)

        let recencyWeights = exponentialRecencyWeights(
            count: sessions.count,
            mostRecentWeight: params.mostRecentSessionWeight,
            decayFactor: params.recencyDecayFactor
        )

        let perSessionMetrics: [SessionMetrics] = sessions.map { pair in
            sessionMetrics(workoutStart: pair.workout.start, sets: pair.exercise.sets)
        }

        let weightedTypicalWeight = weightedAverage(
            perSessionMetrics.map { $0.typicalWeight },
            weights: recencyWeights
        )
        let weightedTypicalReps = weightedAverage(
            perSessionMetrics.map { Double($0.typicalReps) },
            weights: recencyWeights
        )

        let readiness = readinessScore(
            typicalReps: weightedTypicalReps,
            repRange: params.targetRepsPerSet,
            perSession: perSessionMetrics,
            mostRecentWeight: recencyWeights.first ?? 1.0
        )

        let minInc = params.minIncrementKg ?? params.weightIncrement
        let maxInc = max(params.maxIncrementKg ?? (params.weightIncrement * 2.0), minInc)
        let scaledIncrement = roundToHalf(interpolate(minInc, maxInc, readiness))

        let typicalSetsCount = Int(round(weightedAverage(perSessionMetrics.map { Double($0.setCount) }, weights: recencyWeights)))
        let suggestedSetsCount = min(params.maxSets, max(3, typicalSetsCount))

        let midReps = Int((lower + upper) / 2.0)

        let stall = isStalled(perSession: perSessionMetrics, lookback: params.stallLookbackSessions)
        let deloadPercent = interpolate(params.deloadPercentRange.lowerBound, params.deloadPercentRange.upperBound, 1.0 - readiness)

        // Check if weight was increased in the most recent session
        let weightWasIncreased: Bool = {
            guard sessions.count >= 2 else { return false }
            let mostRecent = perSessionMetrics[0]
            let previous = perSessionMetrics[1]
            return mostRecent.typicalWeight > previous.typicalWeight
        }()
        
        // Get most recent session reps
        let mostRecentReps = perSessionMetrics.first?.typicalReps ?? 0
        let mostRecentWeight = perSessionMetrics.first?.typicalWeight ?? 0

        var baseWeight = max(0, weightedTypicalWeight)
        var suggestedReps = midReps
        var noteParts: [String] = []

        if stall {
            baseWeight = baseWeight * (1.0 - deloadPercent)
            noteParts.append("Detected stall; applying ~\(Int(deloadPercent * 100))% deload.")
        } else {
            // NEW LOGIC: Prioritize rep progression over weight progression
            // Only suggest weight increase if reps are very low (3-4 reps)
            let veryLowReps = mostRecentReps <= 4
            
            // If weight was increased and doing 6-7 reps, maintain weight and increase reps
            if weightWasIncreased && mostRecentReps >= 6 && mostRecentReps <= 7 {
                // Maintain weight, suggest increasing reps
                suggestedReps = min(params.targetRepsPerSet.upperBound, mostRecentReps + 1)
                noteParts.append("Weight increased last session; maintain \(Int(baseWeight))kg and aim for \(suggestedReps) reps.")
            }
            // If reps are very low (3-4), suggest weight decrease to get into rep range
            else if veryLowReps {
                baseWeight = max(0, baseWeight - scaledIncrement)
                suggestedReps = max(params.targetRepsPerSet.lowerBound, mostRecentReps + 1)
                noteParts.append("Very low reps (\(mostRecentReps)); reduce by \(scaledIncrement) kg to \(Int(baseWeight))kg and target \(suggestedReps) reps.")
            }
            // If reps are at or above upper bound, can increase weight
            else if weightedTypicalReps >= upper {
                baseWeight += scaledIncrement
                suggestedReps = midReps
                noteParts.append("High reps near ceiling; incremented by \(scaledIncrement) kg to \(Int(baseWeight))kg.")
            }
            // If reps are below lower bound but not very low, maintain weight and increase reps
            else if weightedTypicalReps < lower && !veryLowReps {
                // Don't reduce weight, instead maintain and increase reps
                suggestedReps = min(params.targetRepsPerSet.upperBound, mostRecentReps + 1)
                noteParts.append("Reps below target; maintain \(Int(baseWeight))kg and aim for \(suggestedReps) reps.")
            }
            // Reps in good range - prioritize rep progression first
            else {
                // If we're in the middle range, try to increase reps before weight
                if mostRecentReps < params.targetRepsPerSet.upperBound {
                    suggestedReps = min(params.targetRepsPerSet.upperBound, mostRecentReps + 1)
                    noteParts.append("Reps in target range; maintain \(Int(baseWeight))kg and progress to \(suggestedReps) reps.")
                } else {
                    // Only suggest weight increase if already at max reps
                    baseWeight += scaledIncrement
                    noteParts.append("At max reps; incremented by \(scaledIncrement) kg to \(Int(baseWeight))kg.")
                }
            }
        }

        baseWeight = roundToHalf(baseWeight)

        let backoffPercent = clamp(
            params.backoffPercentRange.upperBound - (1.0 - readiness) * (params.backoffPercentRange.upperBound - params.backoffPercentRange.lowerBound),
            params.backoffPercentRange.lowerBound,
            params.backoffPercentRange.upperBound
        )

        let topSetsCount = max(1, min(2, suggestedSetsCount))
        let backoffSetsCount = max(0, suggestedSetsCount - topSetsCount)
        let backoffWeight = roundToHalf(baseWeight * backoffPercent)

        var plannedSets: [PlannedSet] = []
        plannedSets.append(contentsOf: (0..<topSetsCount).map { _ in
            PlannedSet(reps: suggestedReps, weight: baseWeight)
        })

        if backoffSetsCount > 0 {
            // Backoff sets should have slightly higher reps than main sets
            let backoffReps = min(params.targetRepsPerSet.upperBound, suggestedReps + 1)
            plannedSets.append(contentsOf: (0..<backoffSetsCount).map { _ in
                PlannedSet(reps: backoffReps, weight: backoffWeight)
            })
            noteParts.append("Including backoff sets (~\(Int((1.0 - backoffPercent) * 100))% drop) to manage fatigue.")
        }

        if !stall {
            let readinessPct = Int((readiness * 100.0).rounded())
            noteParts.append("Readiness \(readinessPct)%; dynamic increment \(scaledIncrement) kg.")
        }

        return ExercisePlan(
            exerciseName: exerciseName,
            plannedSets: plannedSets,
            notes: noteParts.joined(separator: " ")
        )
    }
    
    // MARK: - Helpers
    
    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    private struct SessionMetrics {
        let start: Date
        let setCount: Int
        let typicalWeight: Double
        let typicalReps: Int
        let avgRPE: Double?
        let avgRIR: Double?
        let consistency: Double
        let bestVolume: Double
    }

    private static func sessionMetrics(workoutStart: Date, sets: [WorkoutSetRecord]) -> SessionMetrics {
        let workSets = sets.filter { $0.weight > 0 && $0.reps > 0 }
        let setCount = workSets.count

        let typicalWeight: Double = {
            guard !workSets.isEmpty else { return 0 }
            let weights = workSets.map { $0.weight }.sorted()
            return weights[weights.count / 2]
        }()

        let typicalReps: Int = {
            guard !workSets.isEmpty else { return 0 }
            let reps = workSets.map { $0.reps }.sorted()
            return reps[reps.count / 2]
        }()

        let avgRPE: Double? = {
            let values = workSets.compactMap { $0.rpe }
            guard !values.isEmpty else { return nil }
            return average(values)
        }()

        let avgRIR: Double? = {
            let values = workSets.compactMap { Double($0.rir ?? -1) }.filter { $0 >= 0 }
            guard !values.isEmpty else { return nil }
            return average(values)
        }()

        let bestVolume: Double = {
            guard !workSets.isEmpty else { return 0 }
            return workSets.map { $0.weight * Double($0.reps) }.max() ?? 0
        }()

        let consistency: Double = {
            guard !sets.isEmpty else { return 0 }
            let complete = sets.filter { ($0.completedAt != nil) || $0.isCompleted }
            return Double(complete.count) / Double(sets.count)
        }()

        return SessionMetrics(
            start: workoutStart,
            setCount: setCount,
            typicalWeight: typicalWeight,
            typicalReps: typicalReps,
            avgRPE: avgRPE,
            avgRIR: avgRIR,
            consistency: consistency,
            bestVolume: bestVolume
        )
    }

    private static func exponentialRecencyWeights(count: Int, mostRecentWeight: Double, decayFactor: Double) -> [Double] {
        guard count > 0 else { return [] }
        let w0 = clamp(mostRecentWeight, 0.05, 0.95)
        let decay = clamp(decayFactor, 0.05, 0.95)
        var weights: [Double] = []
        weights.reserveCapacity(count)
        for i in 0..<count {
            let w = w0 * pow(decay, Double(i))
            weights.append(w)
        }
        let sum = weights.reduce(0, +)
        guard sum > 0 else { return Array(repeating: 1.0 / Double(count), count: count) }
        return weights.map { $0 / sum }
    }

    private static func weightedAverage(_ values: [Double], weights: [Double]) -> Double {
        guard !values.isEmpty, values.count == weights.count else { return average(values) }
        let sumW = weights.reduce(0, +)
        guard sumW > 0 else { return average(values) }
        var acc: Double = 0
        for i in 0..<values.count {
            acc += values[i] * weights[i]
        }
        return acc
    }

    private static func readinessScore(
        typicalReps: Double,
        repRange: ClosedRange<Int>,
        perSession: [SessionMetrics],
        mostRecentWeight: Double
    ) -> Double {
        let lower = Double(repRange.lowerBound)
        let upper = Double(repRange.upperBound)
        let repProximity: Double = {
            if upper <= lower { return 0.5 }
            let x = (typicalReps - lower) / (upper - lower)
            return clamp(x, 0.0, 1.0)
        }()

        let consistency = weightedAverage(perSession.map { $0.consistency }, weights: exponentialRecencyWeights(count: perSession.count, mostRecentWeight: mostRecentWeight, decayFactor: 0.75))

        let rpeFactor: Double = {
            let rpes = perSession.compactMap { $0.avgRPE }
            guard !rpes.isEmpty else { return 0.5 }
            let avg = average(rpes)
            let x = (9.5 - avg) / 3.0
            return clamp(x, 0.0, 1.0)
        }()

        let rirFactor: Double = {
            let rirs = perSession.compactMap { $0.avgRIR }
            guard !rirs.isEmpty else { return 0.5 }
            let avg = average(rirs)
            let x = avg / 4.0
            return clamp(x, 0.0, 1.0)
        }()

        let autoReg = 0.5 * rpeFactor + 0.5 * rirFactor

        let frequency: Double = {
            guard let mostRecent = perSession.first?.start else { return 0.5 }
            let cutoff = mostRecent.addingTimeInterval(-14.0 * 24.0 * 3600.0)
            let count14 = perSession.filter { $0.start >= cutoff }.count
            return clamp(Double(count14) / 4.0, 0.0, 1.0)
        }()

        let readiness = 0.35 * repProximity + 0.25 * consistency + 0.20 * autoReg + 0.20 * frequency
        return clamp(readiness, 0.0, 1.0)
    }

    private static func isStalled(perSession: [SessionMetrics], lookback: Int) -> Bool {
        let n = min(max(lookback, 3), perSession.count)
        guard n >= 3 else { return false }
        let window = Array(perSession.prefix(n))

        let bestVolumes = window.map { $0.bestVolume }
        let typicalWeights = window.map { $0.typicalWeight }
        let typicalReps = window.map { Double($0.typicalReps) }
        let rpe = window.compactMap { $0.avgRPE }
        let consistency = window.map { $0.consistency }

        let recentVolume = bestVolumes.first ?? 0
        let recentWeight = typicalWeights.first ?? 0
        let recentReps = typicalReps.first ?? 0

        let previousBestVolume = bestVolumes.dropFirst().max() ?? 0
        let previousBestWeight = typicalWeights.dropFirst().max() ?? 0
        let previousAvgReps = {
            let prev = Array(typicalReps.dropFirst())
            guard !prev.isEmpty else { return 0.0 }
            return average(prev)
        }()

        let volumeNotImproving = recentVolume <= previousBestVolume
        let weightNotImproving = recentWeight <= previousBestWeight
        let repsRegressing = recentReps < previousAvgReps
        let rpeHigh = (!rpe.isEmpty) ? (average(rpe) >= 9.0) : false
        let consistencyDropping = (consistency.first ?? 1.0) < 0.7

        let stallSignals = [volumeNotImproving, weightNotImproving, repsRegressing, rpeHigh, consistencyDropping]
        let count = stallSignals.filter { $0 }.count
        return count >= 3
    }

    private static func interpolate(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * clamp(t, 0.0, 1.0)
    }

    private static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }

    private static func roundToHalf(_ x: Double) -> Double {
        (x * 2.0).rounded() / 2.0
    }
}

