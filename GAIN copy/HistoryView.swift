import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Past Workouts")) {
                    if workoutStore.workouts.isEmpty {
                        Text("No workouts yet")
                    } else {
                        ForEach(workoutStore.workouts) { w in
                            NavigationLink(destination: WorkoutDetailView(workout: w)) {
                                VStack(alignment: .leading) {
                                    Text(w.name)
                                    Text("\(w.date, style: .date)")
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
    let workout: Workout

    var body: some View {
        List {
            Section(header: Text("Info")) {
                Text("Name: \(workout.name)")
                Text("Date: \(workout.date, style: .date)")
            }

            Section(header: Text("Exercises")) {
                ForEach(workout.exercises) { ex in
                    VStack(alignment: .leading) {
                        Text(ex.name).bold()
                        ForEach(ex.sets) { s in
                            Text("\(s.reps) × \(s.weight ?? 0, specifier: "%.1f")")
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout")
    }
}
