import Foundation
import Combine

@MainActor
final class DailyStatsStore: ObservableObject {
    static let shared = DailyStatsStore()
    
    @Published private(set) var todayStats: DailyStats
    @Published private(set) var statsHistory: [DailyStats] = []
    @Published var goals: Goals
    
    private let fileURLStats: URL
    private let fileURLGoals: URL
    private var saveCancellable: AnyCancellable?
    
    private init() {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURLStats = docsURL.appendingPathComponent("dailyStats.json")
        fileURLGoals = docsURL.appendingPathComponent("goals.json")
        
        // Load or create today's stats
        self.goals = Goals.defaultGoals
        self.todayStats = DailyStats()
        
        Task {
            await loadGoals()
            await loadStats()
        }
        
        // Debounced auto-save
        saveCancellable = Publishers.CombineLatest3($todayStats, $statsHistory, $goals)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                Task {
                    await self?.saveStats()
                    await self?.saveGoals()
                }
            }
    }
    
    // MARK: - Public API
    
    func updateCalories(_ value: Int) {
        todayStats.calories = value
    }
    
    func updateWater(_ value: Int) {
        todayStats.water = value
    }
    
    func updateSteps(_ value: Int) {
        todayStats.steps = value
    }
    
    func updateSleep(_ value: Double) {
        todayStats.sleep = value
    }
    
    func updateGoals(_ newGoals: Goals) {
        goals = newGoals
    }
    
    // MARK: - Computed Properties
    
    var waterProgress: Double {
        guard goals.dailyWater > 0 else { return 0 }
        return min(Double(todayStats.water) / Double(goals.dailyWater), 1.0)
    }
    
    var calorieProgress: Double {
        guard goals.dailyCalories > 0 else { return 0 }
        return min(Double(todayStats.calories) / Double(goals.dailyCalories), 1.0)
    }
    
    var stepsProgress: Double {
        guard goals.dailySteps > 0 else { return 0 }
        return min(Double(todayStats.steps) / Double(goals.dailySteps), 1.0)
    }
    
    var sleepProgress: Double {
        guard goals.dailySleep > 0 else { return 0 }
        return min(todayStats.sleep / goals.dailySleep, 1.0)
    }
    
    // MARK: - Persistence
    
    private func loadStats() async {
        do {
            let data = try Data(contentsOf: fileURLStats)
            let decoded = try JSONDecoder().decode([DailyStats].self, from: data)
            statsHistory = decoded
            
            // Find or create today's stats
            let calendar = Calendar.current
            if let today = statsHistory.first(where: { calendar.isDateInToday($0.date) }) {
                todayStats = today
            } else {
                todayStats = DailyStats()
                statsHistory.insert(todayStats, at: 0)
            }
        } catch {
            print("Failed to load stats: \(error)")
            todayStats = DailyStats()
            statsHistory = [todayStats]
        }
    }
    
    private func saveStats() async {
        // Update today's stats in history
        let calendar = Calendar.current
        if let index = statsHistory.firstIndex(where: { calendar.isDateInToday($0.date) }) {
            statsHistory[index] = todayStats
        } else {
            statsHistory.insert(todayStats, at: 0)
        }
        
        // Keep last 90 days
        statsHistory = Array(statsHistory.prefix(90))
        
        do {
            let data = try JSONEncoder().encode(statsHistory)
            try data.write(to: fileURLStats, options: .atomic)
        } catch {
            print("Failed to save stats: \(error)")
        }
    }
    
    private func loadGoals() async {
        do {
            let data = try Data(contentsOf: fileURLGoals)
            goals = try JSONDecoder().decode(Goals.self, from: data)
        } catch {
            print("Failed to load goals, using defaults: \(error)")
            goals = Goals.defaultGoals
        }
    }
    
    private func saveGoals() async {
        do {
            let data = try JSONEncoder().encode(goals)
            try data.write(to: fileURLGoals, options: .atomic)
        } catch {
            print("Failed to save goals: \(error)")
        }
    }
}
