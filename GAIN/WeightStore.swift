import Foundation
import Combine

@MainActor
public final class WeightStore: ObservableObject {
    public static let shared = WeightStore()
    
    @Published public private(set) var entries: [WeightEntry] = [] {
        didSet { 
            guard !isLoading else { return }
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
    
    private let filename = "weights.json"
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
    public func add(_ entry: WeightEntry) {
        if entries.isEmpty {
            entries = [entry]
        } else {
            entries.insert(entry, at: 0)
        }
    }

    public func update(_ entry: WeightEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }),
              idx < entries.count else { return }
        entries[idx] = entry
    }
    
    public func delete(id: UUID) {
        entries.removeAll { $0.id == id }
    }
    
    public func clearAll() {
        entries.removeAll()
    }
    
    // MARK: - Persistence
    private func fileURL() throws -> URL {
        let fm = FileManager.default
        let doc = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return doc.appendingPathComponent(filename)
    }
    
    private func performSave() {
        guard !isLoading else { return }
        do {
            let url = try fileURL()
            let data = try encoder.encode(entries)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("WeightStore save error:", error.localizedDescription)
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
                entries = []
                return
            }
            
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                entries = []
                return
            }
            
            let decoded = try decoder.decode([WeightEntry].self, from: data)
            entries = decoded
        } catch {
            print("WeightStore load error:", error.localizedDescription)
            entries = []
        }
    }
}


