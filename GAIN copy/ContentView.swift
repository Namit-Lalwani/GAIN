import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var weightStore: WeightStore

    var body: some View {
        NavigationView {
            List {
                Section("Quick actions") {
                    Button("Add Demo Workout") {
                        let set1 = RepSet(reps: 8, weight: 80)
                        let ex = Exercise(name: "Bench Press", sets: [set1])
                        let w = Workout(name: "Upper Body", exercises: [ex])
                        workoutStore.add(w)
                    }
                    Button("Add Demo Weight") {
                        let entry = WeightEntry(weightKg: 78.2)
                        weightStore.add(entry)
                    }
                }

                Section("Workouts") {
                    ForEach(workoutStore.workouts) { w in
                        VStack(alignment: .leading) {
                            Text(w.name).font(.headline)
                            Text("\(w.date, style: .date)").font(.subheadline)
                        }
                    }
                }

                Section("Weight") {
                    ForEach(weightStore.entries) { e in
                        Text("\(e.date, style: .date): \(String(format: "%.1f", e.weightKg)) kg")
                    }
                }
            }
            .navigationTitle("GAIN")
            .listStyle(InsetGroupedListStyle())
        }
    }
}
