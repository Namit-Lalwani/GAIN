import SwiftUI

struct ExerciseEditor: View {
    @Environment(\.presentationMode) var presentationMode

    @State var exercise: Exercise
    var onSave: (Exercise) -> Void
    var onDelete: () -> Void

    @State private var muscleGroupsText: String = ""

    private let nf: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        Form {
            // Exercise name
            Section(header: Text("Exercise Name")) {
                TextField("Exercise name", text: $exercise.name)
            }

            Section(header: Text("Muscle Groups (tags)")) {
                TextField("e.g. chest, triceps, push", text: $muscleGroupsText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            // Sets (count only; reps/weight are decided during live workout)
            Section(header: Text("Sets")) {
                ForEach(exercise.sets.indices, id: \.self) { sidx in
                    HStack {
                        Text("Set \(sidx + 1)")
                        Spacer()
                        Button {
                            exercise.sets.remove(at: sidx)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus.circle")
                }
            }

            // Save / Delete
            Section {
                Button("Save Exercise") {
                    let tags = muscleGroupsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        .filter { !$0.isEmpty }
                    exercise.muscleGroups = tags.isEmpty ? nil : tags
                    onSave(exercise)
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.headline)

                Button("Delete Exercise") {
                    onDelete()
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle(exercise.name)
        .onAppear {
            if let groups = exercise.muscleGroups {
                muscleGroupsText = groups.joined(separator: ", ")
            }
        }
    }

    private func addSet() {
        exercise.sets.append(
            RepSet(reps: 8, weight: nil, note: nil, isWarmup: false)
        )
    }
}
