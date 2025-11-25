import SwiftUI

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var onSave: (_ save: Bool) -> Void = { _ in }

    @State private var notes: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Summary")) {
                    HStack { Text("Template"); Spacer(); Text(summary.templateName ?? "Custom").foregroundColor(.secondary) }
                    HStack { Text("Duration"); Spacer(); Text(formatTimeInterval(summary.duration)).foregroundColor(.secondary) }
                    HStack { Text("Total Sets"); Spacer(); Text("\(summary.totalSets)").foregroundColor(.secondary) }
                    HStack { Text("Total Reps"); Spacer(); Text("\(summary.totalReps)").foregroundColor(.secondary) }
                    HStack { Text("Total Volume"); Spacer(); Text(String(format: "%.0f", summary.totalVolume)).foregroundColor(.secondary) }
                }

                Section(header: Text("Exercises")) {
                    ForEach(summary.exercises) { ex in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(ex.name).font(.headline)
                                Spacer()
                                Text("\(ex.sets) sets").font(.caption).foregroundColor(.secondary)
                            }
                            HStack {
                                Text("Reps: \(ex.reps)")
                                Spacer()
                                Text(String(format: "Vol: %.0f", ex.volume))
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section(header: Text("Notes (optional)")) {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
            }
            .navigationTitle("Workout Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onSave(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Workout") { onSave(true) }
                }
            }
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    let ex1 = ExerciseSummary(name: "Bench", sets: 4, reps: 40, volume: 2000)
    let s = WorkoutSummary(templateName: "Push", start: Date().addingTimeInterval(-1800), end: Date(), duration: 1800, totalSets: 9, totalReps: 76, totalVolume: 8880, exercises: [ex1])
    WorkoutSummaryView(summary: s) { _ in }
}
