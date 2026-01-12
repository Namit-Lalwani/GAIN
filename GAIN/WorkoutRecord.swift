// WorkoutRecord.swift
import Foundation

public struct WorkoutSetRecord: Identifiable, Codable, Equatable {
    public enum Side: String, Codable, CaseIterable {
        case both
        case left
        case right
    }

    public let id: UUID
    public var reps: Int
    public var weight: Double
    public var rpe: Double?
    public var rir: Int?
    public var note: String?
    public var completedAt: Date?
    public var heartRateAtCompletion: Int?
    public var isCompleted: Bool
    public var side: Side

    public init(
        id: UUID = UUID(),
        reps: Int = 0,
        weight: Double = 0,
        rpe: Double? = nil,
        rir: Int? = nil,
        note: String? = nil,
        completedAt: Date? = nil,
        heartRateAtCompletion: Int? = nil,
        isCompleted: Bool = true,
        side: Side = .both
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.rpe = rpe
        self.rir = rir
        self.note = note
        self.completedAt = completedAt
        self.heartRateAtCompletion = heartRateAtCompletion
        self.isCompleted = isCompleted
        self.side = side
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reps
        case weight
        case rpe
        case rir
        case note
        case completedAt
        case heartRateAtCompletion
        case isCompleted
        case side
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reps = try container.decode(Int.self, forKey: .reps)
        weight = try container.decode(Double.self, forKey: .weight)
        rpe = try container.decodeIfPresent(Double.self, forKey: .rpe)
        rir = try container.decodeIfPresent(Int.self, forKey: .rir)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        heartRateAtCompletion = try container.decodeIfPresent(Int.self, forKey: .heartRateAtCompletion)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? true
        side = try container.decodeIfPresent(Side.self, forKey: .side) ?? .both
    }
}

public struct WorkoutExerciseRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var sets: [WorkoutSetRecord]
    public var notes: String?
    public var muscleGroups: [String]?    // e.g. ["chest","triceps","push"]
    
    public init(
        id: UUID = UUID(),
        name: String,
        sets: [WorkoutSetRecord] = [],
        notes: String? = nil,
        muscleGroups: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.notes = notes
        self.muscleGroups = muscleGroups
    }

    public var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    public var totalVolume: Double { sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight } }
}

public struct WorkoutRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public var templateName: String?
    public var start: Date
    public var end: Date?
    public var duration: TimeInterval
    public var exercises: [WorkoutExerciseRecord]
    public var notes: String?
    public var isUnfinished: Bool

    public init(
        id: UUID = UUID(),
        templateName: String? = nil,
        start: Date = Date(),
        end: Date? = nil,
        duration: TimeInterval = 0,
        exercises: [WorkoutExerciseRecord] = [],
        notes: String? = nil,
        isUnfinished: Bool = false
    ) {
        self.id = id
        self.templateName = templateName
        self.start = start
        self.end = end
        self.duration = duration
        self.exercises = exercises
        self.notes = notes
        self.isUnfinished = isUnfinished
    }

    public var totalVolume: Double {
        exercises.reduce(0.0) { $0 + $1.totalVolume }
    }
    
    public var totalReps: Int {
        exercises.reduce(0) { $0 + $1.totalReps }
    }
    
    public var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case templateName
        case start
        case end
        case duration
        case exercises
        case notes
        case isUnfinished
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        templateName = try container.decodeIfPresent(String.self, forKey: .templateName)
        start = try container.decode(Date.self, forKey: .start)
        end = try container.decodeIfPresent(Date.self, forKey: .end)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        exercises = try container.decode([WorkoutExerciseRecord].self, forKey: .exercises)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isUnfinished = try container.decodeIfPresent(Bool.self, forKey: .isUnfinished) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(templateName, forKey: .templateName)
        try container.encode(start, forKey: .start)
        try container.encodeIfPresent(end, forKey: .end)
        try container.encode(duration, forKey: .duration)
        try container.encode(exercises, forKey: .exercises)
        try container.encodeIfPresent(notes, forKey: .notes)
        if isUnfinished {
            try container.encode(isUnfinished, forKey: .isUnfinished)
        }
    }
}
