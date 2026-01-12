import Foundation

struct BodyStrengthRankingEngine {
    struct AnchorResult: Identifiable {
        let id = UUID()
        let exerciseName: String
        let bestOneRM: Double
        let tier: StrengthStandards.Tier
    }
    
    struct HeadRanking: Identifiable {
        let id: String
        let groupKey: String
        let headName: String
        let tier: StrengthStandards.Tier
        let score0to100: Double
        let setCount: Int
        
        init(groupKey: String, headName: String, tier: StrengthStandards.Tier, score0to100: Double, setCount: Int) {
            self.groupKey = groupKey
            self.headName = headName
            self.tier = tier
            self.score0to100 = min(max(score0to100, 0), 100)
            self.setCount = setCount
            self.id = "\(groupKey)|\(headName)"
        }
    }
    
    struct GroupRanking: Identifiable {
        let id: String
        let displayName: String
        let tier: StrengthStandards.Tier
        let isEstimated: Bool
        let anchorResults: [AnchorResult]
        let headRankings: [HeadRanking]
        
        var bestAnchor: AnchorResult? {
            anchorResults.max(by: { $0.tier < $1.tier })
        }
    }
    
    private struct GroupDescriptor {
        let displayName: String
        let datasetKeys: [String]
        let anchorExercises: [String]
    }
    
    private static let descriptors: [GroupDescriptor] = [
        .init(displayName: "Chest", datasetKeys: ["chest", "upper chest", "lower chest"], anchorExercises: ["Bench Press", "Incline Bench Press", "Dumbbell Bench Press"]),
        .init(displayName: "Back", datasetKeys: ["back", "lats", "upper back"], anchorExercises: ["Deadlift", "Barbell Row", "Pull-Up"]),
        .init(displayName: "Quads", datasetKeys: ["quadriceps", "quads"], anchorExercises: ["Barbell Squat", "Front Squat", "Hack Squat"]),
        .init(displayName: "Hamstrings", datasetKeys: ["hamstrings"], anchorExercises: ["Romanian Deadlift", "Deadlift", "Leg Curl", "Seated Leg Curl"]),
        .init(displayName: "Glutes", datasetKeys: ["glutes"], anchorExercises: ["Hip Thrust", "Barbell Squat", "Deadlift"]),
        .init(displayName: "Deltoids", datasetKeys: ["deltoids", "shoulders", "side delts"], anchorExercises: ["Overhead Press", "Dumbbell Shoulder Press", "Lateral Raise"]),
        .init(displayName: "Biceps", datasetKeys: ["biceps"], anchorExercises: ["Barbell Curl", "Dumbbell Curl", "Preacher Curl"]),
        .init(displayName: "Triceps", datasetKeys: ["triceps"], anchorExercises: ["Close-Grip Bench Press", "Tricep Dips", "Overhead Tricep Extension"]),
        .init(displayName: "Calves", datasetKeys: ["calves"], anchorExercises: ["Standing Calf Raise", "Seated Calf Raise"]),
        .init(displayName: "Core", datasetKeys: ["core", "abs", "abdominals"], anchorExercises: ["Plank", "Barbell Squat", "Deadlift"])
    ]
    
    static func computeRankings(
        workouts: [WorkoutRecord],
        exerciseLibrary: [ExerciseDefinition],
        startDate: Date?,
        endDate: Date?
    ) -> [GroupRanking] {
        guard !workouts.isEmpty else { return [] }
        let headStats = BodyMapEngine.computeMuscleHeadStats(
            workouts: workouts,
            exerciseLibrary: exerciseLibrary,
            startDate: startDate,
            endDate: endDate
        )
        let filteredWorkouts = workouts.filter { record in
            if let startDate = startDate, record.start < startDate { return false }
            if let endDate = endDate, record.start > endDate { return false }
            return true
        }
        let setCounts = focusedSetCounts(workouts: filteredWorkouts, exerciseLibrary: exerciseLibrary)
        var rankings: [GroupRanking] = []
        
        for descriptor in descriptors {
            let datasetKeys = Set(descriptor.datasetKeys.map { $0.lowercased() })
            let relevantStats = headStats.filter { datasetKeys.contains($0.group.lowercased()) }
            let anchorResults = descriptor.anchorExercises.compactMap { anchorResult(for: $0, workouts: workouts) }
            let anchorTier = anchorResults.map { $0.tier }.max()
            let fallbackTier = fallbackTier(for: datasetKeys, stats: headStats)
            let tier = anchorTier ?? fallbackTier
            let isEstimated = anchorTier == nil
            let headRankings = rankingsForHeads(
                stats: relevantStats,
                parentTier: tier,
                setCounts: setCounts,
                descriptorName: descriptor.displayName
            )
            rankings.append(
                GroupRanking(
                    id: descriptor.displayName,
                    displayName: descriptor.displayName,
                    tier: tier,
                    isEstimated: isEstimated,
                    anchorResults: anchorResults,
                    headRankings: headRankings
                )
            )
        }
        
        return rankings.sorted { lhs, rhs in
            if lhs.tier == rhs.tier {
                return lhs.displayName < rhs.displayName
            }
            return lhs.tier > rhs.tier
        }
    }
    
    private static func anchorResult(for exerciseName: String, workouts: [WorkoutRecord]) -> AnchorResult? {
        guard StrengthStandards.thresholdsByExerciseName[exerciseName] != nil else { return nil }
        let oneRM = StrengthAnalytics.bestOneRM(for: exerciseName, workouts: workouts)
        guard oneRM > 0, let tier = StrengthStandards.tier(forOneRM: oneRM, exerciseName: exerciseName) else {
            return nil
        }
        return AnchorResult(exerciseName: exerciseName, bestOneRM: oneRM, tier: tier)
    }
    
    private static func fallbackTier(for datasetKeys: Set<String>, stats: [BodyMapEngine.MuscleHeadStats]) -> StrengthStandards.Tier {
        let relevantScores = stats
            .filter { datasetKeys.contains($0.group.lowercased()) }
            .map { $0.relativeScore }
        guard let maxScore = relevantScores.max(), maxScore > 0 else { return .tier1 }
        return StrengthStandards.tier(forRelativeScore: maxScore / 100.0)
    }
    
    private static func rankingsForHeads(
        stats: [BodyMapEngine.MuscleHeadStats],
        parentTier: StrengthStandards.Tier,
        setCounts: [BodyMapEngine.MuscleHeadKey: Int],
        descriptorName: String
    ) -> [HeadRanking] {
        let rawParentStrength = Double(parentTier.rawValue - 1) / Double(StrengthStandards.Tier.allCases.count - 1)
        // Ensure Novice groups still give their heads a small non-zero baseline so
        // per-head scores can reflect relative usage instead of being locked at 0.
        let parentStrength = max(rawParentStrength, 0.1)
        guard !stats.isEmpty else {
            return [
                HeadRanking(
                    groupKey: descriptorName,
                    headName: "Overall",
                    tier: parentTier,
                    score0to100: parentTier.score0to100,
                    setCount: 0
                )
            ]
        }
        let maxSetCount = stats.compactMap { setCounts[BodyMapEngine.MuscleHeadKey(group: $0.group, head: $0.head)] }.max() ?? 0
        let maxRelativeScore = stats.map { $0.relativeScore }.max() ?? 0
        
        return stats.map { stat in
            let key = BodyMapEngine.MuscleHeadKey(group: stat.group, head: stat.head)
            let setCount = setCounts[key] ?? 0
            let usage: Double
            if maxSetCount > 0 {
                usage = Double(setCount) / Double(maxSetCount)
            } else if maxRelativeScore > 0 {
                usage = stat.relativeScore / maxRelativeScore
            } else {
                usage = 0
            }
            let normalizedScore = min(max(parentStrength * (0.5 + 0.5 * usage), 0), 1)
            let tier = StrengthStandards.tier(forRelativeScore: normalizedScore)
            return HeadRanking(
                groupKey: stat.group,
                headName: stat.head,
                tier: tier,
                score0to100: normalizedScore * 100.0,
                setCount: setCount
            )
        }
        .sorted { lhs, rhs in
            if lhs.tier == rhs.tier {
                return lhs.headName < rhs.headName
            }
            return lhs.tier > rhs.tier
        }
    }
    
    private static func focusedSetCounts(
        workouts: [WorkoutRecord],
        exerciseLibrary: [ExerciseDefinition]
    ) -> [BodyMapEngine.MuscleHeadKey: Int] {
        guard !workouts.isEmpty else { return [:] }
        var counts: [BodyMapEngine.MuscleHeadKey: Int] = [:]
        let definitions = dictionaryByNormalizedName(exerciseLibrary)
        
        for workout in workouts {
            for exercise in workout.exercises {
                let normalizedName = normalizeExerciseName(exercise.name)
                guard let definition = definitions[normalizedName] else { continue }
                let setCount = exercise.sets.count
                guard setCount > 0 else { continue }
                if let targeting = definition.muscleHeadTargeting, !targeting.isEmpty {
                    for (groupName, detail) in targeting {
                        let weights = normalizedWeights(for: detail)
                        let focusedHeads: [String]
                        if weights.isEmpty {
                            focusedHeads = detail.heads
                        } else {
                            let maxWeight = weights.values.max() ?? 0
                            let threshold = max(maxWeight - 0.15, 0)
                            focusedHeads = weights.filter { $0.value >= threshold }.map { $0.key }
                        }
                        for head in focusedHeads {
                            let key = BodyMapEngine.MuscleHeadKey(group: groupName, head: head)
                            counts[key, default: 0] += setCount
                        }
                    }
                } else if let primaries = definition.primaryMuscles {
                    for groupName in primaries {
                        let key = BodyMapEngine.MuscleHeadKey(group: groupName, head: "General")
                        counts[key, default: 0] += setCount
                    }
                }
            }
        }
        
        return counts
    }
    
    private static func dictionaryByNormalizedName(_ exerciseLibrary: [ExerciseDefinition]) -> [String: ExerciseDefinition] {
        var dict: [String: ExerciseDefinition] = [:]
        for definition in exerciseLibrary {
            dict[normalizeExerciseName(definition.name)] = definition
        }
        return dict
    }
    
    private static func normalizeExerciseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private static func normalizedWeights(for targeting: MuscleHeadTargeting) -> [String: Double] {
        var raw: [String: Double] = [:]
        for head in targeting.heads {
            guard let valueString = targeting.targetingDistribution[head], let value = parsePercentageOrRange(valueString) else {
                continue
            }
            raw[head] = value
        }
        let total = raw.values.reduce(0, +)
        guard total > 0 else { return [:] }
        return raw.mapValues { $0 / total }
    }
    
    private static func parsePercentageOrRange(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var core = trimmed
        if let percentIndex = core.firstIndex(of: "%") {
            core = String(core[..<percentIndex])
        }
        let parts = core.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return nil }
        let numbers = parts.compactMap { Double($0) }
        guard !numbers.isEmpty else { return nil }
        let avg = numbers.reduce(0, +) / Double(numbers.count)
        return avg / 100.0
    }
}
