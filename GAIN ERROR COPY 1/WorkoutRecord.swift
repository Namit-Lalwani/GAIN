// WorkoutRecord.swift
import Foundation

public struct WorkoutSetRecord: Identifiable, Codable {
    public let id: UUID
    public var reps: Int
    public var weight: Double
    public var note: String?
    public var completedAt: Date?
    public var heartRateAtCompletion: Int?

    public init(id: UUID = UUID(), reps: Int = 0, weight: Double = 0, note: String? = nil, completedAt: Date? = nil, heartRateAtCompletion: Int? = nil) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.note = note
        self.completedAt = completedAt
        self.heartRateAtCompletion = heartRateAtCompletion
    }
}

public struct WorkoutExerciseRecord: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var sets: [WorkoutSetRecord]

    public init(id: UUID = UUID(), name: String, sets: [WorkoutSetRecord] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }

    public var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    public var totalVolume: Double { sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight } }
}

public struct WorkoutRecord: Identifiable, Codable {
    public let id: UUID
    public var templateName: String?
    public var start: Date
    public var end: Date?
    public var duration: TimeInterval
    public var exercises: [WorkoutExerciseRecord]
    public var notes: String?

    public init(id: UUID = UUID(), templateName: String? = nil, start: Date = Date(), end: Date? = nil, duration: TimeInterval = 0, exercises: [WorkoutExerciseRecord] = [], notes: String? = nil) {
        self.id = id
        self.templateName = templateName
        self.start = start
        self.end = end
        self.duration = duration
        self.exercises = exercises
        self.notes = notes
    }

    public var totalVolume: Double {
        exercises.reduce(0.0) { $0 + $1.totalVolume }
    }

    public var totalReps: Int {
        exercises.reduce(0) { $0 + $1.totalReps }
    }
}
