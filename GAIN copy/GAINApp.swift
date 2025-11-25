import SwiftUI

@main
struct GAINApp: App {
    @StateObject var workoutStore = WorkoutStore()
    @StateObject var weightStore = WeightStore()
    @StateObject var routineStore = RoutineStore()
    @StateObject var templateStore = TemplateStore()
    @StateObject var waterStore = WaterStore()
    @StateObject var calorieStore = CalorieStore()
    @StateObject var stepsStore = StepsStore()
    @StateObject var sleepStore = SleepStore()
    @StateObject var goalsStore = GoalsStore()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(workoutStore)
                .environmentObject(weightStore)
                .environmentObject(routineStore)
                .environmentObject(waterStore)
                .environmentObject(calorieStore)
                .environmentObject(stepsStore)
                .environmentObject(sleepStore)
                .environmentObject(goalsStore)
                .environmentObject(templateStore)


        }
    }
}

