import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Analytics")) {
                    NavigationLink(destination: AIInsightsView()) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.blue)
                            Text("AI Insights")
                                .font(.headline)
                        }
                    }
                    
                    NavigationLink(destination: ExerciseProgressView()) {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.green)
                            Text("Exercise Progress")
                                .font(.headline)
                        }
                    }
                }
                
                Section(header: Text("Past Workouts")) {
                    if workoutStore.workouts.isEmpty {
                        Text("No workouts yet")
                    } else {
                        ForEach(workoutStore.workouts) { w in
                            NavigationLink(destination: WorkoutDetailView(workout: w)) {
                                VStack(alignment: .leading) {
                                    Text(w.templateName ?? "Custom Workout")
                                    Text("\(w.start, style: .date)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

// Simple WorkoutDetailView
struct WorkoutDetailView: View {
    let workout: WorkoutRecord

    var body: some View {
        List {
            Section(header: Text("Info")) {
                Text("Template: \(workout.templateName ?? "Custom")")
                Text("Date: \(workout.start, style: .date)")
            }

            Section(header: Text("Exercises")) {
                ForEach(workout.exercises) { ex in
                    VStack(alignment: .leading) {
                        Text(ex.name).bold()
                        ForEach(ex.sets) { s in
                            Text("\(s.reps) × \(s.weight, specifier: "%.1f")")
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout")
    }
}
