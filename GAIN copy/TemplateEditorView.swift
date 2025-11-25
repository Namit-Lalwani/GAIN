import SwiftUI

struct TemplateEditorView: View {
    @EnvironmentObject var templateStore: TemplateStore
    @Environment(\.presentationMode) var presentationMode

    @State var template: TemplateModel

    var body: some View {
        Form {
            Section(header: Text("Template Name")) {
                TextField("Template name", text: $template.name)
            }

            Section(header: Text("Exercises")) {
                ForEach(template.exercises.indices, id: \.self) { idx in
                    let exercise = template.exercises[idx]

                    NavigationLink(destination: ExerciseEditor(
                        exercise: exercise,
                        onSave: { updated in
                            template.exercises[idx] = updated
                        },
                        onDelete: {
                            template.exercises.remove(at: idx)
                        }
                    )) {
                        HStack {
                            Text(exercise.name)
                            Spacer()
                            Text("\(exercise.sets.count) sets")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Button(action: addExercise) {
                    Label("Add Exercise", systemImage: "plus")
                }
            }

            Section {
                Button("Save Template") {
                    saveTemplate()
                }
                .font(.headline)
            }
        }
        .navigationTitle(template.name.isEmpty ? "New Template" : template.name)
    }

    private func addExercise() {
        let new = Exercise(name: "New Exercise", sets: [])
        template.exercises.append(new)
    }

    private func saveTemplate() {
        if let i = templateStore.templates.firstIndex(where: { $0.id == template.id }) {
            templateStore.templates[i] = template
        } else {
            templateStore.add(template)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
