import Foundation
import Combine

@MainActor
final class ProgressiveOverloadSettingsStore: ObservableObject {
    static let shared = ProgressiveOverloadSettingsStore()
    
    enum ProgressionCategory: String, Codable, CaseIterable {
        case strengthDominant
        case hypertrophy
        case endurance
    }

    struct ExerciseOverloadSettings: Identifiable, Codable {
        let id: UUID
        var exerciseName: String
        var weightIncrementKg: Double
        var category: ProgressionCategory?
        var targetRepsPerSet: ClosedRange<Int>?
        var minIncrementKg: Double?
        var maxIncrementKg: Double?
        var deloadEveryWeeks: Int?
        
        init(
            id: UUID = UUID(),
            exerciseName: String,
            weightIncrementKg: Double = 2.5,
            category: ProgressionCategory? = nil,
            targetRepsPerSet: ClosedRange<Int>? = nil,
            minIncrementKg: Double? = nil,
            maxIncrementKg: Double? = nil,
            deloadEveryWeeks: Int? = nil
        ) {
            self.id = id
            self.exerciseName = exerciseName
            self.weightIncrementKg = weightIncrementKg
            self.category = category
            self.targetRepsPerSet = targetRepsPerSet
            self.minIncrementKg = minIncrementKg
            self.maxIncrementKg = maxIncrementKg
            self.deloadEveryWeeks = deloadEveryWeeks
        }
    }
    
    @Published private(set) var settingsByExerciseKey: [String: ExerciseOverloadSettings] = [:] {
        didSet { scheduleSave() }
    }
    
    private let filename = "overload_settings.json"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        if let loaded: [String: ExerciseOverloadSettings] = FileManager.load([String: ExerciseOverloadSettings].self, from: filename) {
            settingsByExerciseKey = loaded
        } else {
            settingsByExerciseKey = [:]
        }
    }
    
    private func normalizedKey(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    func increment(for exerciseName: String) -> Double {
        let key = normalizedKey(for: exerciseName)
        return settingsByExerciseKey[key]?.weightIncrementKg ?? 2.5
    }

    func category(for exerciseName: String) -> ProgressionCategory? {
        let key = normalizedKey(for: exerciseName)
        return settingsByExerciseKey[key]?.category
    }

    func targetRepsPerSet(for exerciseName: String) -> ClosedRange<Int>? {
        let key = normalizedKey(for: exerciseName)
        return settingsByExerciseKey[key]?.targetRepsPerSet
    }

    func minIncrementKg(for exerciseName: String) -> Double? {
        let key = normalizedKey(for: exerciseName)
        return settingsByExerciseKey[key]?.minIncrementKg
    }

    func maxIncrementKg(for exerciseName: String) -> Double? {
        let key = normalizedKey(for: exerciseName)
        return settingsByExerciseKey[key]?.maxIncrementKg
    }

    func deloadEveryWeeks(for exerciseName: String) -> Int? {
        let key = normalizedKey(for: exerciseName)
        return settingsByExerciseKey[key]?.deloadEveryWeeks
    }

    func setCategory(_ value: ProgressionCategory?, for exerciseName: String) {
        let key = normalizedKey(for: exerciseName)
        var settings = settingsByExerciseKey[key] ?? ExerciseOverloadSettings(exerciseName: exerciseName)
        settings.category = value
        settingsByExerciseKey[key] = settings
    }

    func setTargetRepsPerSet(_ value: ClosedRange<Int>?, for exerciseName: String) {
        let key = normalizedKey(for: exerciseName)
        var settings = settingsByExerciseKey[key] ?? ExerciseOverloadSettings(exerciseName: exerciseName)
        settings.targetRepsPerSet = value
        settingsByExerciseKey[key] = settings
    }

    func setMinIncrementKg(_ value: Double?, for exerciseName: String) {
        let key = normalizedKey(for: exerciseName)
        var settings = settingsByExerciseKey[key] ?? ExerciseOverloadSettings(exerciseName: exerciseName)
        settings.minIncrementKg = value
        settingsByExerciseKey[key] = settings
    }

    func setMaxIncrementKg(_ value: Double?, for exerciseName: String) {
        let key = normalizedKey(for: exerciseName)
        var settings = settingsByExerciseKey[key] ?? ExerciseOverloadSettings(exerciseName: exerciseName)
        settings.maxIncrementKg = value
        settingsByExerciseKey[key] = settings
    }

    func setDeloadEveryWeeks(_ value: Int?, for exerciseName: String) {
        let key = normalizedKey(for: exerciseName)
        var settings = settingsByExerciseKey[key] ?? ExerciseOverloadSettings(exerciseName: exerciseName)
        settings.deloadEveryWeeks = value
        settingsByExerciseKey[key] = settings
    }

    func applyDefaultProfile(for category: ProgressionCategory, exerciseName: String) {
        let key = normalizedKey(for: exerciseName)
        var settings = settingsByExerciseKey[key] ?? ExerciseOverloadSettings(exerciseName: exerciseName)

        settings.category = category
        switch category {
        case .strengthDominant:
            settings.targetRepsPerSet = 3...6
            settings.minIncrementKg = 2.5
            settings.maxIncrementKg = 5.0
            settings.deloadEveryWeeks = 6
        case .hypertrophy:
            settings.targetRepsPerSet = 6...12
            settings.minIncrementKg = 1.25
            settings.maxIncrementKg = 2.5
            settings.deloadEveryWeeks = 5
        case .endurance:
            settings.targetRepsPerSet = 12...20
            settings.minIncrementKg = 0.5
            settings.maxIncrementKg = 1.25
            settings.deloadEveryWeeks = 4
        }

        settingsByExerciseKey[key] = settings
    }
    
    func setIncrement(_ value: Double, for exerciseName: String) {
        let key = normalizedKey(for: exerciseName)
        var settings = settingsByExerciseKey[key] ?? ExerciseOverloadSettings(exerciseName: exerciseName)
        settings.weightIncrementKg = value
        settingsByExerciseKey[key] = settings
    }
    
    private func scheduleSave() {
        FileManager.save(settingsByExerciseKey, to: filename)
    }
}
