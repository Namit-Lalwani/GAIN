// AdvancedProgressiveOverloadEngine.swift
import Foundation

// MARK: - Core Enums

public enum TrainingGoal: String, Codable, CaseIterable {
    case maximalStrength
    case hypertrophy
    case strengthEndurance
    case power
    case muscularEndurance
}

public enum ExperienceLevel: String, Codable, CaseIterable {
    case novice
    case intermediate
    case advanced
}

public enum ExerciseType: String, Codable {
    case compound
    case accessory
}

// MARK: - Training Profile (Goal + Experience)

public struct TrainingProfile: Codable {
    public let goal: TrainingGoal
    public let experience: ExperienceLevel

    // Prescribed ranges
    public let loadPercentRange: ClosedRange<Double>   // %1RM, e.g. 0.65...0.85
    public let setsRange: ClosedRange<Int>
    public let repsRange: ClosedRange<Int>
    public let restSecondsRange: ClosedRange<Int>
    public let progressionFocus: String                // simple description

    public init(
        goal: TrainingGoal,
        experience: ExperienceLevel,
        loadPercentRange: ClosedRange<Double>,
        setsRange: ClosedRange<Int>,
        repsRange: ClosedRange<Int>,
        restSecondsRange: ClosedRange<Int>,
        progressionFocus: String
    ) {
        self.goal = goal
        self.experience = experience
        self.loadPercentRange = loadPercentRange
        self.setsRange = setsRange
        self.repsRange = repsRange
        self.restSecondsRange = restSecondsRange
        self.progressionFocus = progressionFocus
    }

    // Default templates based on goal + experience
    public static func `default`(goal: TrainingGoal, experience: ExperienceLevel) -> TrainingProfile {
        switch (goal, experience) {
        case (.maximalStrength, .novice):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.60...0.75,
                setsRange: 3...4,
                repsRange: 3...6,
                restSecondsRange: 120...240,
                progressionFocus: "Form, anatomical adaptation, basic strength"
            )

        case (.maximalStrength, .intermediate):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.75...0.85,
                setsRange: 4...6,
                repsRange: 1...5,
                restSecondsRange: 180...300,
                progressionFocus: "Volume + intensity, weekly to monthly PRs"
            )

        case (.maximalStrength, .advanced):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.80...1.00,
                setsRange: 3...5,
                repsRange: 1...4,
                restSecondsRange: 180...300,
                progressionFocus: "Peaking, heavy singles and doubles"
            )

        case (.hypertrophy, .novice):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.60...0.70,
                setsRange: 3...4,
                repsRange: 8...12,
                restSecondsRange: 60...90,
                progressionFocus: "Time under tension, technique"
            )

        case (.hypertrophy, .intermediate):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.65...0.80,
                setsRange: 3...5,
                repsRange: 6...12,
                restSecondsRange: 45...90,
                progressionFocus: "High weekly volume, varied rep ranges"
            )

        case (.hypertrophy, .advanced):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.70...0.85,
                setsRange: 4...6,
                repsRange: 6...10,
                restSecondsRange: 45...90,
                progressionFocus: "Specialization blocks, high density work"
            )

        case (.strengthEndurance, _):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.50...0.75,
                setsRange: 2...4,
                repsRange: 8...15,
                restSecondsRange: 60...120,
                progressionFocus: "Sustained strength and fatigue resistance"
            )

        case (.power, _):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.30...0.60,
                setsRange: 3...5,
                repsRange: 1...5,
                restSecondsRange: 120...300,
                progressionFocus: "Explosive intent, bar speed"
            )

        case (.muscularEndurance, _):
            return TrainingProfile(
                goal: goal,
                experience: experience,
                loadPercentRange: 0.40...0.67,
                setsRange: 2...3,
                repsRange: 15...25,
                restSecondsRange: 20...60,
                progressionFocus: "High reps, short rests, metabolic stress"
            )
        }
    }
}

// MARK: - One-Rep Max Calculator

public struct OneRepMaxCalculator {

    // Brzycki
    public static func brzycki(weight: Double, reps: Int) -> Double {
        weight * (36.0 / (37.0 - Double(reps)))
    }

    // Epley
    public static func epley(weight: Double, reps: Int) -> Double {
        weight * (1.0 + Double(reps) / 30.0)
    }

    // Wathan
    public static func wathan(weight: Double, reps: Int) -> Double {
        (100.0 * weight) / (48.8 + (53.8 * exp(-0.075 * Double(reps))))
    }

    /// Robust estimated 1RM: average of multiple formulas, only for ≤10 reps.
    public static func estimatedOneRM(weight: Double, reps: Int) -> Double {
        guard reps > 0, reps <= 10, weight > 0 else { return 0 }
        let brz = brzycki(weight: weight, reps: reps)
        let epl = epley(weight: weight, reps: reps)
        let wat = wathan(weight: weight, reps: reps)
        return (brz + epl + wat) / 3.0
    }
}

// MARK: - Autoregulation Engine (RPE + APRE-style)

public struct AutoregulationEngine {

    // RPE / RIR based adjustment
    public func adjustLoadByRPE(currentWeight: Double, targetRPE: Double, actualRPE: Double) -> Double {
        let difference = actualRPE - targetRPE
        if difference > 1.0 {
            return currentWeight * 0.93 // Too hard, drop ~7%
        } else if difference < -1.0 {
            return currentWeight * 1.05 // Too easy, add 5%
        }
        return currentWeight
    }

    // Performance-based adjustment (APRE-style)
    public func adjustLoadByPerformance(
        currentWeight: Double,
        targetReps: Int,
        actualReps: Int,
        exerciseType: ExerciseType
    ) -> Double {
        let diff = actualReps - targetReps
        let multiplier = exerciseType == .compound ? 1.05 : 1.03

        if diff >= 3 {
            return currentWeight * multiplier * multiplier   // +5–10%
        } else if diff >= 1 {
            return currentWeight * multiplier                // +3–5%
        } else if diff <= -2 {
            return currentWeight * 0.90                      // -10%
        } else if diff == -1 {
            return currentWeight * 0.95                      // -5%
        }
        return currentWeight
    }
}

// MARK: - Periodization Models (high-level)

public enum PeriodizationModel: String, Codable {
    case linear
    case undulating
    case block
}

public struct PeriodizationPhase: Codable {
    public let name: String
    public let goal: TrainingGoal
    public let durationWeeks: Int
    public let notes: String
}

/// Simple high-level template of a periodized plan.
/// (You can store an array of these in a routine/template later.)
public struct PeriodizationPlan: Codable {
    public let model: PeriodizationModel
    public let phases: [PeriodizationPhase]
    
    public static func linearNoviceTemplate() -> PeriodizationPlan {
        PeriodizationPlan(
            model: .linear,
            phases: [
                PeriodizationPhase(
                    name: "Anatomical Adaptation",
                    goal: .muscularEndurance,
                    durationWeeks: 4,
                    notes: "10–15 reps @ 50–60% 1RM"
                ),
                PeriodizationPhase(
                    name: "Hypertrophy",
                    goal: .hypertrophy,
                    durationWeeks: 4,
                    notes: "8–12 reps @ 65–75% 1RM"
                ),
                PeriodizationPhase(
                    name: "Strength",
                    goal: .maximalStrength,
                    durationWeeks: 4,
                    notes: "4–6 reps @ 80–90% 1RM"
                ),
                PeriodizationPhase(
                    name: "Peak/Power",
                    goal: .power,
                    durationWeeks: 2,
                    notes: "1–3 reps @ 90–100% 1RM"
                )
            ]
        )
    }
}

// MARK: - Recommendation Types

public struct WorkoutRecommendation {
    public let targetWeight: Double
    public let reps: Int
    public let sets: Int
    public let restSeconds: Int
    public let reason: String
    public let confidence: Double   // 0–1

    public init(
        targetWeight: Double,
        reps: Int,
        sets: Int,
        restSeconds: Int,
        reason: String,
        confidence: Double
    ) {
        self.targetWeight = targetWeight
        self.reps = reps
        self.sets = sets
        self.restSeconds = restSeconds
        self.reason = reason
        self.confidence = confidence
    }
}

// MARK: - Progression Engine

public enum AdvancedProgressionEngine {

    /// Suggest next session prescription for a single exercise,
    /// based on last set, goal, experience and optional autoregulation.
    public static func suggestNextSession(
        exerciseName: String,
        exerciseType: ExerciseType,
        lastWeight: Double,
        lastReps: Int,
        estimated1RM: Double?,
        goal: TrainingGoal,
        experience: ExperienceLevel,
        targetRPE: Double? = nil,
        actualRPE: Double? = nil
    ) -> WorkoutRecommendation {
        let profile = TrainingProfile.default(goal: goal, experience: experience)
        let auto = AutoregulationEngine()

        // 1) Determine target load as % of 1RM if we have it
        let basePercent = (profile.loadPercentRange.lowerBound + profile.loadPercentRange.upperBound) / 2.0
        var weightFrom1RM: Double = lastWeight

        if let oneRM = estimated1RM, oneRM > 0 {
            weightFrom1RM = oneRM * basePercent
        }

        // 2) Start from last weight or 1RM-based weight
        var nextWeight = max(weightFrom1RM, lastWeight * 0.95) // avoid huge drops
        var reason = "Based on goal \(goal.rawValue) and experience \(experience.rawValue)."
        var confidence = estimated1RM != nil ? 0.9 : 0.7

        // 3) Apply simple goal-specific progression (reps vs weight)
        let targetRepsMid = Int((Double(profile.repsRange.lowerBound) + Double(profile.repsRange.upperBound)) / 2.0)
        var nextReps = targetRepsMid

        switch goal {
        case .maximalStrength:
            // Double progression: reps to top of small range, then weight
            if lastReps >= profile.repsRange.upperBound {
                nextWeight *= 1.025
                nextReps = profile.repsRange.lowerBound
                reason += " Hit top of rep range; increasing weight slightly."
            } else if lastReps < profile.repsRange.lowerBound {
                nextWeight = lastWeight
                nextReps = lastReps + 1
                reason += " Building toward target rep range."
            }

        case .hypertrophy:
            if lastReps >= profile.repsRange.upperBound {
                nextWeight *= 1.05
                nextReps = profile.repsRange.lowerBound
                reason += " Completed hypertrophy rep range; increasing load by ~5%."
            } else {
                nextWeight = lastWeight
                nextReps = min(profile.repsRange.upperBound, lastReps + 1)
                reason += " Progressive rep increase within hypertrophy range."
            }

        case .strengthEndurance, .muscularEndurance:
            if lastReps >= profile.repsRange.upperBound {
                nextWeight *= 1.03
                nextReps = profile.repsRange.lowerBound
                reason += " Endurance capacity improved; small load increase."
            } else {
                nextWeight = lastWeight
                nextReps = min(profile.repsRange.upperBound, lastReps + 2)
                reason += " Adding reps to build endurance."
            }

        case .power:
            // Keep reps low and focus on bar speed; mostly adjust weight down if too slow/hard.
            nextReps = min(profile.repsRange.upperBound, max(profile.repsRange.lowerBound, lastReps))
            reason += " Maintain low reps, focus on explosiveness."
        }

        // 4) Apply RPE-based autoregulation if available
        if let target = targetRPE, let actual = actualRPE {
            let adjusted = auto.adjustLoadByRPE(currentWeight: nextWeight, targetRPE: target, actualRPE: actual)
            if adjusted != nextWeight {
                reason += " Adjusted by RPE feedback."
                confidence = min(confidence + 0.05, 1.0)
                nextWeight = adjusted
            }
        }

        // 5) Clamp sets/rest from profile midpoints
        let sets = Int((Double(profile.setsRange.lowerBound) + Double(profile.setsRange.upperBound)) / 2.0)
        let rest = Int((Double(profile.restSecondsRange.lowerBound) + Double(profile.restSecondsRange.upperBound)) / 2.0)

        // Round weight to 0.5 kg
        nextWeight = max(0, (nextWeight * 2.0).rounded() / 2.0)

        return WorkoutRecommendation(
            targetWeight: nextWeight,
            reps: max(1, nextReps),
            sets: sets,
            restSeconds: rest,
            reason: reason,
            confidence: confidence
        )
    }
}
