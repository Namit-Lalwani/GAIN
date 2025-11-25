import SwiftUI

@main
struct GAINApp: App {
    // Initialize stores lazily to prevent crashes
    @StateObject private var workoutStore = WorkoutStore.shared
    @StateObject private var sessionStore = SessionStore.shared
    @StateObject private var weightStore = WeightStore.shared
    @StateObject private var routineStore = RoutineStore()
    @StateObject private var templateStore = TemplateStore()
    @StateObject private var waterStore = WaterStore()
    @StateObject private var calorieStore = CalorieStore()
    @StateObject private var stepsStore = StepsStore()
    @StateObject private var sleepStore = SleepStore()
    @StateObject private var goalsStore = GoalsStore()
    
    init() {
        // Initialize Watch connectivity receiver after app is ready
        DispatchQueue.main.async {
            _ = iPhoneSessionReceiver.shared
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(workoutStore)
                .environmentObject(sessionStore)
                .environmentObject(weightStore)
                .environmentObject(routineStore)
                .environmentObject(templateStore)
                .environmentObject(waterStore)
                .environmentObject(calorieStore)
                .environmentObject(stepsStore)
                .environmentObject(sleepStore)
                .environmentObject(goalsStore)
        }
    }
}

