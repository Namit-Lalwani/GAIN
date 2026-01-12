import Foundation

/// Analytics for mapping workout volume into detailed muscle-head scores
/// using the anatomically rich metadata from exercises.json.
struct BodyMapEngine {
    // MARK: - Types
    
    struct MuscleHeadKey: Hashable {
        let group: String   // e.g. "Chest"
        let head: String    // e.g. "Clavicular (Upper)"
    }
    
    struct MuscleHeadStats: Identifiable {
        let id: String
        let group: String
        let head: String
        let totalVolume: Double
        let totalSets: Int
        let totalReps: Int
        /// 0–100 score relative to the most trained region in the sample
        let relativeScore: Double
        
        init(group: String,
             head: String,
             totalVolume: Double,
             totalSets: Int,
             totalReps: Int,
             relativeScore: Double) {
            self.group = group
            self.head = head
            self.totalVolume = totalVolume
            self.totalSets = totalSets
            self.totalReps = totalReps
            self.relativeScore = relativeScore
            self.id = "\(group)|\(head)"
        }
    }
    
    // MARK: - Public API
    
    /// Compute per–muscle-head training stats from historical workouts.
    /// - Parameters:
    ///   - workouts: All workout records to consider.
    ///   - exerciseLibrary: Definitions loaded from exercises.json.
    ///   - startDate: Optional lower bound for workout.start.
    ///   - endDate: Optional upper bound for workout.start.
    /// - Returns: Stats for each (muscle group, head) pair seen in the data.
    static func computeMuscleHeadStats(
        workouts: [WorkoutRecord],
        exerciseLibrary: [ExerciseDefinition],
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [MuscleHeadStats] {
        // Filter workouts by optional date range
        let filteredWorkouts = workouts.filter { record in
            if let startDate = startDate, record.start < startDate { return false }
            if let endDate = endDate, record.start > endDate { return false }
            return true
        }
        
        // Index exercise definitions by normalized name
        var definitionsByName: [String: ExerciseDefinition] = [:]
        for def in exerciseLibrary {
            let key = BodyMapEngine.normalizeName(def.name)
            definitionsByName[key] = def
        }
        
        var volumeByRegion: [MuscleHeadKey: Double] = [:]
        var setsByRegion: [MuscleHeadKey: Int] = [:]
        var repsByRegion: [MuscleHeadKey: Int] = [:]
        
        for workout in filteredWorkouts {
            for exerciseRecord in workout.exercises {
                let keyName = BodyMapEngine.normalizeName(exerciseRecord.name)
                let exerciseVolume = exerciseRecord.totalVolume
                let exerciseSets = exerciseRecord.sets.count
                let exerciseReps = exerciseRecord.totalReps
                
                guard exerciseVolume > 0 || exerciseSets > 0 || exerciseReps > 0 else {
                    continue
                }
                
                if let def = definitionsByName[keyName] {
                    // Use detailed head-level targeting if available
                    if let targetingMap = def.muscleHeadTargeting, !targetingMap.isEmpty {
                        for (groupName, targetingDetail) in targetingMap {
                            let weights = normalizedWeights(for: targetingDetail)
                            if !weights.isEmpty {
                                for (headName, weight) in weights {
                                    accumulate(
                                        group: groupName,
                                        head: headName,
                                        weight: weight,
                                        exerciseVolume: exerciseVolume,
                                        exerciseSets: exerciseSets,
                                        exerciseReps: exerciseReps,
                                        volumeByRegion: &volumeByRegion,
                                        setsByRegion: &setsByRegion,
                                        repsByRegion: &repsByRegion
                                    )
                                }
                            } else {
                                // Fallback: split evenly across declared heads
                                let heads = targetingDetail.heads
                                guard !heads.isEmpty else { continue }
                                let equal = 1.0 / Double(heads.count)
                                for headName in heads {
                                    accumulate(
                                        group: groupName,
                                        head: headName,
                                        weight: equal,
                                        exerciseVolume: exerciseVolume,
                                        exerciseSets: exerciseSets,
                                        exerciseReps: exerciseReps,
                                        volumeByRegion: &volumeByRegion,
                                        setsByRegion: &setsByRegion,
                                        repsByRegion: &repsByRegion
                                    )
                                }
                            }
                        }
                    } else if let primaries = def.primaryMuscles, !primaries.isEmpty {
                        // Coarse fallback: distribute across primary muscles using a generic "General" head
                        let share = 1.0 / Double(primaries.count)
                        for groupName in primaries {
                            accumulate(
                                group: groupName,
                                head: "General",
                                weight: share,
                                exerciseVolume: exerciseVolume,
                                exerciseSets: exerciseSets,
                                exerciseReps: exerciseReps,
                                volumeByRegion: &volumeByRegion,
                                setsByRegion: &setsByRegion,
                                repsByRegion: &repsByRegion
                            )
                        }
                    } else if let groups = exerciseRecord.muscleGroups, !groups.isEmpty {
                        // Final fallback: use muscleGroups on the record itself if present
                        let share = 1.0 / Double(groups.count)
                        for groupName in groups {
                            accumulate(
                                group: groupName,
                                head: "General",
                                weight: share,
                                exerciseVolume: exerciseVolume,
                                exerciseSets: exerciseSets,
                                exerciseReps: exerciseReps,
                                volumeByRegion: &volumeByRegion,
                                setsByRegion: &setsByRegion,
                                repsByRegion: &repsByRegion
                            )
                        }
                    }
                } else if let groups = exerciseRecord.muscleGroups, !groups.isEmpty {
                    // No definition found in the library – still try to attribute volume using muscleGroups
                    let share = 1.0 / Double(groups.count)
                    for groupName in groups {
                        accumulate(
                            group: groupName,
                            head: "General",
                            weight: share,
                            exerciseVolume: exerciseVolume,
                            exerciseSets: exerciseSets,
                            exerciseReps: exerciseReps,
                            volumeByRegion: &volumeByRegion,
                            setsByRegion: &setsByRegion,
                            repsByRegion: &repsByRegion
                        )
                    }
                }
            }
        }
        
        let maxVolume = volumeByRegion.values.max() ?? 0
        guard maxVolume > 0 else {
            return []
        }
        
        var results: [MuscleHeadStats] = []
        for (key, volume) in volumeByRegion {
            let sets = setsByRegion[key] ?? 0
            let reps = repsByRegion[key] ?? 0
            let score = max(0, min(100, (volume / maxVolume) * 100.0))
            results.append(
                MuscleHeadStats(
                    group: key.group,
                    head: key.head,
                    totalVolume: volume,
                    totalSets: sets,
                    totalReps: reps,
                    relativeScore: score
                )
            )
        }
        
        // Highest-scored regions first by default
        return results.sorted { lhs, rhs in
            if lhs.relativeScore == rhs.relativeScore {
                if lhs.group == rhs.group {
                    return lhs.head < rhs.head
                }
                return lhs.group < rhs.group
            }
            return lhs.relativeScore > rhs.relativeScore
        }
    }
    
    /// Compute per–muscle-head strength stats using estimated 1RM instead of volume.
    /// This looks at the best set for each exercise (via StrengthAnalytics) and
    /// attributes that strength to muscle heads using the same targeting data.
    /// relativeScore is 0–100 scaled by the strongest region.
    static func computeMuscleHeadStrengthStats(
        workouts: [WorkoutRecord],
        exerciseLibrary: [ExerciseDefinition],
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> [MuscleHeadStats] {
        let filteredWorkouts = workouts.filter { record in
            if let startDate = startDate, record.start < startDate { return false }
            if let endDate = endDate, record.start > endDate { return false }
            return true
        }
        
        guard !filteredWorkouts.isEmpty else { return [] }
        
        // Index exercise definitions by normalized name
        var definitionsByName: [String: ExerciseDefinition] = [:]
        for def in exerciseLibrary {
            let key = BodyMapEngine.normalizeName(def.name)
            definitionsByName[key] = def
        }
        
        // Use StrengthAnalytics to get per-exercise best sets and estimated 1RM.
        let samples = StrengthAnalytics.exerciseSamples(from: filteredWorkouts)
        guard !samples.isEmpty else { return [] }
        
        var strengthByRegion: [MuscleHeadKey: Double] = [:]
        
        for sample in samples {
            let keyName = BodyMapEngine.normalizeName(sample.exerciseName)
            guard let def = definitionsByName[keyName] else { continue }
            let est1RM = sample.estimated1RM
            guard est1RM > 0 else { continue }
            
            if let targetingMap = def.muscleHeadTargeting, !targetingMap.isEmpty {
                for (groupName, targetingDetail) in targetingMap {
                    let weights = normalizedWeights(for: targetingDetail)
                    if !weights.isEmpty {
                        for (headName, weight) in weights {
                            accumulateStrength(
                                group: groupName,
                                head: headName,
                                weight: weight,
                                estimated1RM: est1RM,
                                strengthByRegion: &strengthByRegion
                            )
                        }
                    } else {
                        let heads = targetingDetail.heads
                        guard !heads.isEmpty else { continue }
                        let equal = 1.0 / Double(heads.count)
                        for headName in heads {
                            accumulateStrength(
                                group: groupName,
                                head: headName,
                                weight: equal,
                                estimated1RM: est1RM,
                                strengthByRegion: &strengthByRegion
                            )
                        }
                    }
                }
            } else if let primaries = def.primaryMuscles, !primaries.isEmpty {
                let share = 1.0 / Double(primaries.count)
                for groupName in primaries {
                    accumulateStrength(
                        group: groupName,
                        head: "General",
                        weight: share,
                        estimated1RM: est1RM,
                        strengthByRegion: &strengthByRegion
                    )
                }
            }
        }
        
        let maxStrength = strengthByRegion.values.max() ?? 0
        guard maxStrength > 0 else { return [] }
        
        var results: [MuscleHeadStats] = []
        for (key, strength) in strengthByRegion {
            let score = max(0, min(100, (strength / maxStrength) * 100.0))
            results.append(
                MuscleHeadStats(
                    group: key.group,
                    head: key.head,
                    totalVolume: strength, // here 'volume' represents best weighted 1RM
                    totalSets: 0,
                    totalReps: 0,
                    relativeScore: score
                )
            )
        }
        
        return results.sorted { lhs, rhs in
            if lhs.relativeScore == rhs.relativeScore {
                if lhs.group == rhs.group {
                    return lhs.head < rhs.head
                }
                return lhs.group < rhs.group
            }
            return lhs.relativeScore > rhs.relativeScore
        }
    }
    
    // MARK: - Internal helpers
    
    private static func normalizeName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private static func accumulate(
        group: String,
        head: String,
        weight: Double,
        exerciseVolume: Double,
        exerciseSets: Int,
        exerciseReps: Int,
        volumeByRegion: inout [MuscleHeadKey: Double],
        setsByRegion: inout [MuscleHeadKey: Int],
        repsByRegion: inout [MuscleHeadKey: Int]
    ) {
        guard weight > 0 else { return }
        let key = MuscleHeadKey(group: group, head: head)
        volumeByRegion[key, default: 0] += exerciseVolume * weight
        // Sets/reps attribution is approximate when split, but good enough for analytics
        setsByRegion[key, default: 0] += Int((Double(exerciseSets) * weight).rounded())
        repsByRegion[key, default: 0] += Int((Double(exerciseReps) * weight).rounded())
    }
    
    /// Strength aggregation uses the *best* weighted estimated 1RM seen for a region.
    private static func accumulateStrength(
        group: String,
        head: String,
        weight: Double,
        estimated1RM: Double,
        strengthByRegion: inout [MuscleHeadKey: Double]
    ) {
        guard weight > 0, estimated1RM > 0 else { return }
        let key = MuscleHeadKey(group: group, head: head)
        let weighted = estimated1RM * weight
        let current = strengthByRegion[key] ?? 0
        if weighted > current {
            strengthByRegion[key] = weighted
        }
    }
    
    /// Convert the textual targetingDistribution values (e.g. "55%", "60-70%", "Varies with cable height")
    /// into normalized numeric weights per head.
    private static func normalizedWeights(for targeting: MuscleHeadTargeting) -> [String: Double] {
        var raw: [String: Double] = [:]
        
        for head in targeting.heads {
            guard let valueString = targeting.targetingDistribution[head] else {
                continue
            }
            if let value = parsePercentageOrRange(valueString) {
                raw[head] = value
            }
        }
        
        let total = raw.values.reduce(0, +)
        guard total > 0 else { return [:] }
        
        var result: [String: Double] = [:]
        for (head, value) in raw {
            result[head] = value / total
        }
        return result
    }
    
    /// Parse values like "55%", "60-70%", "60-70", returning a 0–1 fraction,
    /// or nil for non-numeric descriptions (e.g. "Varies with cable height").
    private static func parsePercentageOrRange(_ string: String) -> Double? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        var core = trimmed
        if let percentIndex = core.firstIndex(of: "%") {
            core = String(core[..<percentIndex])
        }
        
        let parts = core
            .split(separator: "-")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return nil }
        
        if parts.count == 1 {
            if let value = Double(parts[0]) {
                return value / 100.0
            }
            return nil
        } else {
            let numbers = parts.compactMap { Double($0) }
            guard !numbers.isEmpty else { return nil }
            let avg = numbers.reduce(0, +) / Double(numbers.count)
            return avg / 100.0
        }
    }
}
