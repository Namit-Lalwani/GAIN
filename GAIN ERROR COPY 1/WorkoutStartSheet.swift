import SwiftUI

struct WorkoutStartSheet: View {
    var templates: [WorkoutTemplate]
    var startWorkout: (_ template: WorkoutTemplate?) -> Void

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button {
                        startWorkout(nil) // start custom workout
                    } label: {
                        Label("Start Custom Workout", systemImage: "plus.circle")
                    }
                }

                Section(header: Text("Saved Templates")) {
                    ForEach(templates) { template in
                        Button {
                            startWorkout(template)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                    .font(.headline)
                                if let day = template.assignedDay {
                                    Text("Assigned to: \(day)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Start Workout")
        }
    }
}
