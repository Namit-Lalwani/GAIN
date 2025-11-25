import SwiftUI

struct WorkoutListView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    var body: some View {
        VStack {
            List {
                ForEach(workoutStore.workouts) { workout in
                    Text(workout.name)
                }
            }

            Button("+ Add Workout") {
                // Will implement later
            }
            .padding()
        }
        .navigationTitle("Workouts")
    }
}
