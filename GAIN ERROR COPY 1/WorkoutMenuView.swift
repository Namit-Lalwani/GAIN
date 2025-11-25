import SwiftUI

struct WorkoutMenuView: View {
    @EnvironmentObject var routineStore: RoutineStore
    @EnvironmentObject var workoutStore: WorkoutStore

    @State private var showingStart = false
    @State private var showingContinueConfirm = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Today label + assigned template
                let todayTemplate = routineStore.templateFor(date: Date())

                VStack {
                    Text("Today")
                        .font(.headline)
                    Text("\(todayTemplate)")
                        .font(.title2)
                        .bold()
                }
                .padding(.top, 16)

                Button(action: {
                    showingStart = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke())
                }
                .padding(.horizontal)

                Button(action: {
                    // Continue: check unfinished
                    if workoutStore.workouts.contains(where: { $0.notes == "unfinished" }) {
                        showingContinueConfirm = true
                    } else {
                        // nothing to continue - could show alert here
                        return
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Continue Workout")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke())
                }
                .padding(.horizontal)
                .alert(isPresented: $showingContinueConfirm) {
                    Alert(title: Text("Resume unfinished workout?"),
                          message: Text("Resume or Delete the unfinished workout."),
                          primaryButton: .default(Text("Resume")) {
                            if let unfinished = workoutStore.workouts.first(where: { $0.notes == "unfinished" }) {
                                // Navigate to workout session with unfinished workout
                                // This would require passing the workout to WorkoutSessionView
                                // For now, just remove the "unfinished" note
                                var updated = unfinished
                                updated.notes = nil
                                workoutStore.update(updated)
                            }
                          },
                          secondaryButton: .destructive(Text("Delete")) {
                            if let unfinished = workoutStore.workouts.first(where: { $0.notes == "unfinished" }) {
                                workoutStore.delete(id: unfinished.id)
                            }
                          })
                }

                NavigationLink(destination: TodaySummaryView()) {
                    HStack {
                        Image(systemName: "doc.plaintext")
                        Text("Today's Summary")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke())
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Workout")
            .sheet(isPresented: $showingStart) {
                // Start selection sheet
                StartWorkoutSheet()
            }
        }
    }
}
