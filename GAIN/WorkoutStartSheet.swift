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
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.gainCardSoft)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.gainAccent)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start Custom Workout")
                                    .font(.headline)
                                    .foregroundColor(.gainTextPrimary)
                                Text("Build a workout from scratch")
                                    .font(.caption)
                                    .foregroundColor(.gainTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gainTextSecondary)
                        }
                        .padding(8)
                    }
                }

                Section(header: Text("Saved Templates")) {
                    ForEach(templates) { template in
                        Button {
                            startWorkout(template)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gainCardSoft)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "list.bullet")
                                        .foregroundColor(.gainAccent)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundColor(.gainTextPrimary)
                                    Text("\(template.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundColor(.gainTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gainTextSecondary)
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
