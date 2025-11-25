import Foundation
import SwiftUI
import Combine   // <<-- required for ObservableObject & @Published

final class WaterStore: ObservableObject {
    @Published var waterToday: Int = 0 // ml
}

final class CalorieStore: ObservableObject {
    @Published var caloriesToday: Int = 0
}

final class StepsStore: ObservableObject {
    @Published var stepsToday: Int = 0
}

final class SleepStore: ObservableObject {
    @Published var sleepHours: Double = 0
}

final class GoalsStore: ObservableObject {
    @Published var dailyWaterGoal: Int = 3000
    @Published var dailyCalorieGoal: Int = 2500
    @Published var dailyStepsGoal: Int = 8000
    @Published var weightGoal: Double = 0
}
