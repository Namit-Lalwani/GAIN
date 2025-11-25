// WorkoutStore.swift
import Foundation
import Combine

// Note: RepSet, ExerciseRecord, and WorkoutRecord are defined in WorkoutRecord.swift
// This file only contains the WorkoutStore class

// -----------------
// STORE
// -----------------

@MainActor
public final class WorkoutStore: ObservableObject {
    public static let shared = WorkoutStore()

    @Published public private(set) var records: [WorkoutRecord] = [] {
        didSet { 
            guard !isLoading else { return }
            // Debounce saves
            saveDebouncer.cancel()
            saveDebouncer = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.performSave()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: saveDebouncer)
        }
    }
    
    private var saveDebouncer = DispatchWorkItem {}
    
    // Compatibility property for code that uses 'workouts'
    public var workouts: [WorkoutRecord] {
        records
    }

    private let filename = "workouts.json"
    private var isLoading = false

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        // Initialize synchronously, load asynchronously after a brief delay
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.performLoad()
            }
        }
    }

    // MARK: - CRUD
    public func add(_ record: WorkoutRecord) {
        if records.isEmpty {
            records = [record]
        } else {
            records.insert(record, at: 0)
        }
    }

    public func update(_ record: WorkoutRecord) {
        guard let idx = records.firstIndex(where: { $0.id == record.id }),
              idx < records.count else { return }
        records[idx] = record
    }

    public func delete(id: UUID) {
        records.removeAll { $0.id == id }
    }
    
    public func delete(at indexSet: IndexSet) {
        for index in indexSet {
            if index < records.count {
                records.remove(at: index)
            }
        }
    }

    public func clearAll() {
        records.removeAll()
    }
    
    // MARK: - Export
    public func exportCSV() async throws -> URL {
        let fm = FileManager.default
        let doc = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = doc.appendingPathComponent("workouts_export.csv")
        
        var csv = "Date,Template,Duration (min),Exercises,Total Volume\n"
        
        for record in records {
            let dateStr = ISO8601DateFormatter().string(from: record.start)
            let template = record.templateName ?? "Custom"
            let durationMin = Int(record.duration / 60)
            let exerciseNames = record.exercises.map { $0.name }.joined(separator: "; ")
            let volume = String(format: "%.0f", record.totalVolume)
            
            csv += "\"\(dateStr)\",\"\(template)\",\(durationMin),\"\(exerciseNames)\",\(volume)\n"
        }
        
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Persistence (simple file-based)
    private func fileURL() throws -> URL {
        let fm = FileManager.default
        let doc = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return doc.appendingPathComponent(filename)
    }

    private func performSave() {
        guard !isLoading else { return }
        do {
            let url = try fileURL()
            let data = try encoder.encode(records)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("WorkoutStore save error:", error.localizedDescription)
        }
    }
    
    // Note: save() is not called directly - debouncing is handled in didSet

    @MainActor
    private func performLoad() async {
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            let url = try fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                records = []
                return
            }
            
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                records = []
                return
            }
            
            let decoded = try decoder.decode([WorkoutRecord].self, from: data)
            records = decoded
        } catch {
            print("WorkoutStore load error:", error.localizedDescription)
            records = []
        }
    }
}
