import Foundation

struct DailyStats: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var calories: Int
    var water: Int // in ml
    var steps: Int
    var sleep: Double // in hours
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        calories: Int = 0,
        water: Int = 0,
        steps: Int = 0,
        sleep: Double = 0
    ) {
        self.id = id
        self.date = date
        self.calories = calories
        self.water = water
        self.steps = steps
        self.sleep = sleep
    }
}

struct Goals: Codable, Equatable {

    var dailyCalories: Int
    var dailyWater: Int
    var dailySteps: Int
    var dailySleep: Double

    // ✅ Possible calorie goals
    static let calorieOptions: [Int] = [
        1800,
        2000,
        2200,
        2400,
        2600
    ]

    // ✅ Default goals with RANDOM calorie selection
    static let defaultGoals = Goals(
        dailyCalories: calorieOptions.randomElement() ?? 2000,
        dailyWater: 2500,
        dailySteps: 10000,
        dailySleep: 8.0
    )
}
