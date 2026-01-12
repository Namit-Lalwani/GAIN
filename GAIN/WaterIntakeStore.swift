import Foundation
import Combine

struct WaterIntakeEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let amountMl: Int
    let containerName: String?
    
    init(id: UUID = UUID(), date: Date = Date(), amountMl: Int, containerName: String? = nil) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
        self.containerName = containerName
    }
}

struct WaterContainer: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let volumeMl: Int
    let icon: String
}

@MainActor
final class WaterIntakeStore: ObservableObject {
    @Published private(set) var entries: [WaterIntakeEntry] = []
    @Published private(set) var containers: [WaterContainer] = []
    
    private let fileURLEntries: URL
    private let fileURLContainers: URL
    
    private var saveCancellable: AnyCancellable?
    
    init() {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURLEntries = docsURL.appendingPathComponent("waterEntries.json")
        fileURLContainers = docsURL.appendingPathComponent("waterContainers.json")
        
        Task {
            await loadEntries()
            await loadContainers()
            if containers.isEmpty {
                loadDefaultContainers()
            }
        }
        
        saveCancellable = Publishers.CombineLatest($entries, $containers)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                Task {
                    await self?.saveEntries()
                    await self?.saveContainers()
                }
            }
    }
    
    // MARK: - Public API
    
    var todayEntries: [WaterIntakeEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.date) }
    }
    
    var todayTotalMl: Int {
        todayEntries.reduce(0) { $0 + $1.amountMl }
    }
    
    func add(amountMl: Int, containerName: String? = nil) {
        guard amountMl > 0 else { return }
        let entry = WaterIntakeEntry(amountMl: amountMl, containerName: containerName)
        entries.insert(entry, at: 0)
        syncWithDailyStats()
    }
    
    func delete(entry: WaterIntakeEntry) {
        entries.removeAll { $0.id == entry.id }
        syncWithDailyStats()
    }
    
    func addContainer(name: String, volumeMl: Int, icon: String) {
        let container = WaterContainer(id: UUID(), name: name, volumeMl: volumeMl, icon: icon)
        containers.append(container)
    }
    
    // MARK: - Private
    
    private func syncWithDailyStats() {
        let total = todayTotalMl
        DailyStatsStore.shared.updateWater(total)
    }
    
    private func loadDefaultContainers() {
        containers = [
            WaterContainer(id: UUID(), name: "Glass", volumeMl: 200, icon: "cup.and.saucer.fill"),
            WaterContainer(id: UUID(), name: "Bottle", volumeMl: 500, icon: "bottle.fill"),
            WaterContainer(id: UUID(), name: "Shaker", volumeMl: 1000, icon: "figure.strengthtraining.traditional"),
            WaterContainer(id: UUID(), name: "Big Bottle", volumeMl: 2000, icon: "waterbottle.fill")
        ]
    }
    
    private func loadEntries() async {
        do {
            let data = try Data(contentsOf: fileURLEntries)
            let decoded = try JSONDecoder().decode([WaterIntakeEntry].self, from: data)
            entries = decoded
        } catch {
            entries = []
        }
    }
    
    private func saveEntries() async {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURLEntries, options: .atomic)
        } catch {
            // ignore for now
        }
    }
    
    private func loadContainers() async {
        do {
            let data = try Data(contentsOf: fileURLContainers)
            let decoded = try JSONDecoder().decode([WaterContainer].self, from: data)
            containers = decoded
        } catch {
            containers = []
        }
    }
    
    private func saveContainers() async {
        do {
            let data = try JSONEncoder().encode(containers)
            try data.write(to: fileURLContainers, options: .atomic)
        } catch {
            // ignore for now
        }
    }
}
