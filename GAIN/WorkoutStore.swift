// WorkoutStore.swift
import Foundation
import Combine
import os.log

@MainActor
final class WorkoutStore: ObservableObject {
    // MARK: - Singleton
    public static let shared = WorkoutStore()
    
    // MARK: - Properties
    @Published private(set) var records: [WorkoutRecord] = [] {
        didSet {
            scheduleSave()
        }
    }
    
    private let logger = Logger(
        subsystem: "com.yourdomain.GAIN",
        category: String(describing: WorkoutStore.self)
    )
    
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let saveQueue: DispatchQueue
    
    // Debouncer
    private let saveDebouncer = PassthroughSubject<Void, Never>()
    private var saveCancellable: AnyCancellable?
    
    // MARK: - Initialization
    private init(
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileManager = fileManager
        self.encoder = encoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = decoder
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.saveQueue = DispatchQueue(label: "com.yourdomain.GAIN.workoutstore.save", qos: .utility)
        
        setupSaveDebouncer()
        
        // Initial load
        Task {
            await load()
        }
    }
    
    // MARK: - Public API
    
    /// Adds a new workout record
    public func add(_ record: WorkoutRecord) {
        records.insert(record, at: 0)
        logger.debug("Added workout record with ID: \(record.id.uuidString)")
    }
    
    /// Updates an existing workout record
    public func update(_ record: WorkoutRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            logger.error("Failed to find workout record with ID: \(record.id.uuidString)")
            return
        }
        records[index] = record
        logger.debug("Updated workout record with ID: \(record.id.uuidString)")
    }
    
    /// Deletes a workout record by ID
    public func delete(id: UUID) {
        let before = records.count
        records.removeAll { $0.id == id }
        if records.count < before {
            logger.debug("Deleted workout record with ID: \(id.uuidString)")
        } else {
            logger.warning("Attempted to delete non-existent workout record with ID: \(id.uuidString)")
        }
    }

    // MARK: - CSV Export
    /// Export all workouts to a temporary CSV file and return its URL.
    public func exportCSV() async throws -> URL {
        // Snapshot records on the main actor
        let recordsToExport = records

        // Build CSV content
        var csv = "id,date,template,durationSeconds,totalVolume,totalReps\n"
        let formatter = ISO8601DateFormatter()

        for record in recordsToExport {
            let id = record.id.uuidString
            let dateString = formatter.string(from: record.start)
            let template = record.templateName ?? "Custom"
            let duration = Int(record.duration)
            let volume = record.totalVolume
            let reps = record.totalReps

            let line = "\(id),\(dateString),\(template.replacingOccurrences(of: ",", with: " ")),\(duration),\(volume),\(reps)\n"
            csv.append(line)
        }

        // Write to a temporary file in the documents directory
        let docs = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let exportURL = docs.appendingPathComponent("workouts_export_\(UUID().uuidString).csv")

        try csv.write(to: exportURL, atomically: true, encoding: .utf8)
        logger.debug("Exported CSV to \(exportURL.path, privacy: .public)")
        return exportURL
    }
    
    // MARK: - Debounced save
    
    private func setupSaveDebouncer() {
        saveCancellable = saveDebouncer
            .debounce(for: .seconds(1), scheduler: saveQueue)
            .sink { [weak self] _ in
                self?.performSave()
            }
    }
    
    private func scheduleSave() {
        saveDebouncer.send(())
    }
    
    // MARK: - Persistence
    
    private func fileURL() throws -> URL {
        try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("workouts.json")
    }
    
    private func load() async {
        do {
            let url = try fileURL()
            guard fileManager.fileExists(atPath: url.path) else {
                logger.debug("No existing workout data found, starting with empty store")
                return
            }
            
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([WorkoutRecord].self, from: data)
            
            // @MainActor so this is safe
            self.records = decoded.sorted { $0.start > $1.start }
            logger.debug("Successfully loaded \(decoded.count) workout records")
        } catch {
            logger.error("Failed to load workout data: \(error.localizedDescription)")
            self.records = []
        }
    }
    
    private func performSave() {
        let recordsToSave = self.records
        
        do {
            let url = try fileURL()
            let data = try encoder.encode(recordsToSave)
            
            // temp file then move
            let tempURL = url.deletingLastPathComponent()
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("tmp")
            
            try data.write(to: tempURL, options: .atomic)
            
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            
            try fileManager.moveItem(at: tempURL, to: url)
            logger.debug("Successfully saved \(recordsToSave.count) workout records")
        } catch {
            logger.error("Failed to save workout data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Support
extension WorkoutStore {
    static var preview: WorkoutStore = {
        let store = WorkoutStore()
        store.records = [
            WorkoutRecord(
                templateName: "Full Body",
                start: Date().addingTimeInterval(-86400),
                end: Date().addingTimeInterval(-82800),
                duration: 3600,
                exercises: [
                    WorkoutExerciseRecord(
                        name: "Squats",
                        sets: [
                            WorkoutSetRecord(reps: 10, weight: 60),
                            WorkoutSetRecord(reps: 10, weight: 60)
                        ]
                    )
                ]
            )
        ]
        return store
    }()
}
