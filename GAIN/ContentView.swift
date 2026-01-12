import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutMenuView()
                .tabItem {
                    Label("Workout", systemImage: "dumbbell.fill")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WorkoutStore.shared)
            .environmentObject(TemplateStore())
            .environmentObject(WeightStore.shared)
            .environmentObject(ProgressiveOverloadSettingsStore.shared)
            .environmentObject(DailyStatsStore.shared)
            .environmentObject(StepsSleepHealthStore.shared)
            .environmentObject(DeveloperDataStore.shared)
    }
}
