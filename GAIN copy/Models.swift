import Foundation

// MARK: - Models

struct RepSet: Identifiable, Codable {
    let id: UUID
    var reps: Int
    var weight: Double?    // nil means bodyweight/no load
    var note: String?
    var isWarmup: Bool

    init(id: UUID = UUID(), reps: Int, weight: Double? = nil, note: String? = nil, isWarmup: Bool = false) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.note = note
        self.isWarmup = isWarmup
    }
}

struct Exercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var sets: [RepSet]

    init(id: UUID = UUID(), name: String, sets: [RepSet] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct Workout: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var exercises: [Exercise]
    var notes: String?

    init(id: UUID = UUID(), name: String = "Workout", date: Date = Date(), exercises: [Exercise] = [], notes: String? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.exercises = exercises
        self.notes = notes
    }
}

struct WeightEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var weightKg: Double   // store in kg internally; convert for UI if needed

    init(id: UUID = UUID(), date: Date = Date(), weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}
