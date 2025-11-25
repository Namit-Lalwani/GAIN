//
// WorkoutStore.swift
// GAIN - persistence for workouts with per-set HR + timestamp
//

import Foundation
import Combine

// MARK: - Models

public struct SetRecord: Codable, Identifiable {
    public let id: UUID
    public var reps: Int
    public var weight: Double
    public var note: String
    public var isCompleted: Bool

    // New: optional per-set metadata
    public var completedAt: Date?
    public var heartRateAtCompletion: Double?

    public init(id: UUID = UUID(),
                reps: Int = 0,
                weight: Double = 0,
                note: String = "",
                isCompleted: Bool = false,
                completedAt: Date? = nil,
                heartRateAtCompletion: Double? = nil) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.note = note
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.heartRateAtCompletion = heartRateAtCompletion
    }
}

public struct ExerciseRecord: Codable, Identifiable {
    public let id: UUID
    public var name: String
    public var sets: [SetRecord]

    public init(id: UUID = UUID(), name: String, sets: [SetRecord] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }

    public var totalReps: Int {
        sets.reduce(0) { $0 + $1.reps }
    }
    public var totalVolume: Double {
        sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
    }
}

public struct WorkoutRecord: Codable, Identifiable {
    public let id: UUID
    public var templateName: String?
    public var start: Date
    public var end: Date
    public var duration: TimeInterval
    public var totalSets: Int
    public var totalReps: Int
    public var totalVolume: Double
    public var exercises: [ExerciseRecord]
    public var notes: String?

    public init(id: UUID = UUID(),
                templateName: String? = nil,
                start: Date,
                end: Date,
                duration: TimeInterval,
                totalSets: Int,
                totalReps: Int,
                totalVolume: Double,
                exercises: [ExerciseRecord],
                notes: String? = nil) {
        self.id = id
        self.templateName = templateName
        self.start = start
        self.end = end
        self.duration = duration
        self.totalSets = totalSets
        self.totalReps = totalReps
        self.totalVolume = totalVolume
        self.exercises = exercises
        self.notes = notes
    }
}

// MARK: - WorkoutStore

@MainActor
public final class WorkoutStore: ObservableObject {
    public static let shared = WorkoutStore()

    @Published public private(set) var workouts: [WorkoutRecord] = []

    private let filename = "workouts.json"
    private var cancellables = Set<AnyCancellable>()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        loadAsync()

        $workouts
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.saveAsync() }
            }
            .store(in: &cancellables)
    }

    // MARK: - API

    public func addWorkout(templateName: String? = nil,
                           start: Date,
                           end: Date,
                           exercises: [ExerciseRecord],
                           notes: String? = nil) -> WorkoutRecord {
        let totalSets = exercises.reduce(0) { $0 + $1.sets.count }
        let totalReps = exercises.reduce(0) { $0 + $1.totalReps }
        let totalVolume = exercises.reduce(0.0) { $0 + $1.totalVolume }
        let duration = end.timeIntervalSince(start)

        let record = WorkoutRecord(templateName: templateName,
                                   start: start,
                                   end: end,
                                   duration: duration,
                                   totalSets: totalSets,
                                   totalReps: totalReps,
                                   totalVolume: totalVolume,
                                   exercises: exercises,
                                   notes: notes)

        DispatchQueue.main.async {
            self.workouts.insert(record, at: 0)
        }
        return record
    }

    public func delete(id: UUID) {
        DispatchQueue.main.async {
            self.workouts.removeAll { $0.id == id }
        }
    }

    public func delete(at offsets: IndexSet) {
        DispatchQueue.main.async {
            self.workouts.remove(atOffsets: offsets)
        }
    }

    public func clearAll() {
        DispatchQueue.main.async {
            self.workouts.removeAll()
        }
    }

    public func saveNow() async {
        await saveAsync()
    }

    public func exportCSV() async throws -> URL {
        let header = """
        id,templateName,start_iso,end_iso,duration_seconds,totalSets,totalReps,totalVolume,exerciseName,setIndex,reps,weight,note,completedAt,hr
        """
        var rows: [String] = [header]

        for w in workouts {
            for ex in w.exercises {
                for (setIndex, s) in ex.sets.enumerated() {
                    func csvEscape(_ str: String?) -> String {
                        guard let s = str else { return "" }
                        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
                        return "\"\(escaped)\""
                    }
                    let completedAt = s.completedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
                    let hr = s.heartRateAtCompletion.map { String(format: "%.1f", $0) } ?? ""
                    let row = """
                    \(w.id.uuidString),\(csvEscape(w.templateName)),\(iso8601(w.start)),\(iso8601(w.end)),\(Int(w.duration)),\(w.totalSets),\(w.totalReps),\(String(format: "%.2f", w.totalVolume)),\(csvEscape(ex.name)),\(setIndex + 1),\(s.reps),\(String(format: "%.2f", s.weight)),\(csvEscape(s.note)),\(completedAt),\(hr)
                    """
                    rows.append(row)
                }
            }
        }

        let csv = rows.joined(separator: "\n")
        let url = try fileURLFor("workouts_export.csv")
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Persistence

    private func loadAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let url = self.dataFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else { return }

            do {
                let data = try Data(contentsOf: url)
                let decoded = try self.decoder.decode([WorkoutRecord].self, from: data)
                DispatchQueue.main.async {
                    self.workouts = decoded
                }
            } catch {
                print("WorkoutStore load error:", error)
            }
        }
    }

    private func saveAsync() async {
        let toSave = self.workouts
        do {
            let data = try encoder.encode(toSave)
            let url = dataFileURL()
            try data.write(to: url, options: .atomic)
        } catch {
            print("WorkoutStore save error:", error)
        }
    }

    // MARK: - Helpers

    private func dataFileURL() -> URL {
        (try? fileURLFor(filename)) ?? FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }

    private func fileURLFor(_ name: String) throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent(name)
    }

    private func iso8601(_ d: Date) -> String {
        ISO8601DateFormatter().string(from: d)
    }
}
