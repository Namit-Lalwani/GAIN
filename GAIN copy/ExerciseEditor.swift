import SwiftUI

struct ExerciseEditor: View {
    @Environment(\.presentationMode) var presentationMode

    @State var exercise: Exercise
    var onSave: (Exercise) -> Void
    var onDelete: () -> Void

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

            // Sets
            Section(header: Text("Sets")) {
                ForEach(exercise.sets.indices, id: \.self) { sidx in
                    HStack {
                        Stepper("Reps: \(exercise.sets[sidx].reps)",
                                value: $exercise.sets[sidx].reps,
                                in: 0...100)

                        Spacer()

                        TextField(
                            "Weight",
                            value: Binding(
                                get: { exercise.sets[sidx].weight ?? 0 },
                                set: { exercise.sets[sidx].weight = $0 == 0 ? nil : $0 }
                            ),
                            formatter: nf
                        )
                        .keyboardType(.decimalPad)
                        .frame(width: 80)

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
    }

    private func addSet() {
        exercise.sets.append(
            RepSet(reps: 8, weight: nil, note: nil, isWarmup: false)
        )
    }
}
