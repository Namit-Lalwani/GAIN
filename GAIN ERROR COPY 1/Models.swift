// Models.swift
import Foundation

// --- Rep set (single set of an exercise) ---
public struct RepSet: Identifiable, Codable {
    public let id: UUID
    public var reps: Int
    public var weight: Double?
    public var note: String?
    public var completedAt: Date?
    public var heartRateAtCompletion: Double?
    public var isWarmup: Bool

    public init(id: UUID = UUID(),
                reps: Int = 0,
                weight: Double? = nil,
                note: String? = nil,
                completedAt: Date? = nil,
                heartRateAtCompletion: Double? = nil,
                isWarmup: Bool = false) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.note = note
        self.completedAt = completedAt
        self.heartRateAtCompletion = heartRateAtCompletion
        self.isWarmup = isWarmup
    }
}

// --- Exercise inside a workout ---
public struct Exercise: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var sets: [RepSet]

    public init(id: UUID = UUID(), name: String, sets: [RepSet] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}


public struct Workout: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var date: Date
    public var exercises: [Exercise]

    public init(id: UUID = UUID(), name: String, date: Date = Date(), exercises: [Exercise] = []) {
        self.id = id
        self.name = name
        self.date = date
        self.exercises = exercises
    }

    // derived convenience
    public var duration: TimeInterval {
        // placeholder: you can compute using start/end timestamps when you add them later
        return 0
    }
}

// --- Weight entry ---
public struct WeightEntry: Identifiable, Codable {
    public let id: UUID
    public var date: Date
    public var weight: Double   // kg

    public init(id: UUID = UUID(), date: Date = Date(), weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

// --- Workout Summary (for completed workouts) ---
public struct ExerciseSummary: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var sets: Int
    public var reps: Int
    public var volume: Double
    
    public init(id: UUID = UUID(), name: String, sets: Int, reps: Int, volume: Double) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.volume = volume
    }
}

public struct WorkoutSummary: Identifiable, Codable {
    public let id: UUID
    public var templateName: String?
    public var start: Date
    public var end: Date
    public var duration: TimeInterval
    public var totalSets: Int
    public var totalReps: Int
    public var totalVolume: Double
    public var exercises: [ExerciseSummary]
    
    public init(id: UUID = UUID(),
                templateName: String? = nil,
                start: Date,
                end: Date,
                duration: TimeInterval,
                totalSets: Int,
                totalReps: Int,
                totalVolume: Double,
                exercises: [ExerciseSummary]) {
        self.id = id
        self.templateName = templateName
        self.start = start
        self.end = end
        self.duration = duration
        self.totalSets = totalSets
        self.totalReps = totalReps
        self.totalVolume = totalVolume
        self.exercises = exercises
    }
}
