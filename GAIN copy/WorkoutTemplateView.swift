import SwiftUI

// MARK: - Model
struct WorkoutTemplate: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var exercises: [String]
    var assignedDay: String?

    init(id: UUID = UUID(), name: String, exercises: [String] = [], assignedDay: String? = nil) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.assignedDay = assignedDay
    }
}

// MARK: - Main List View
struct WorkoutTemplateView: View {
    @State private var templates: [WorkoutTemplate] = [
        WorkoutTemplate(name: "Push Day", exercises: ["Bench Press", "Overhead Press"]),
        WorkoutTemplate(name: "Leg Day", exercises: ["Squat", "Romanian Deadlift"])
    ]

    @State private var showingNewTemplate = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(templates.indices, id: \.self) { idx in
                        let template = templates[idx]
                        NavigationLink(destination: WorkoutTemplateDetailView(template: $templates[idx])) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                if let day = template.assignedDay {
                                    Text("Assigned to: \(day)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(template.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .onDelete { indexSet in
                        templates.remove(atOffsets: indexSet)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewTemplate = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingNewTemplate) {
                NewTemplateView(templates: $templates)
            }
        }
    }
}

// MARK: - New Template Modal
struct NewTemplateView: View {
    @Binding var templates: [WorkoutTemplate]
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Template Name")) {
                    TextField("Enter name", text: $name)
                }
            }
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        templates.append(WorkoutTemplate(name: trimmed))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Template Detail / Editor
struct WorkoutTemplateDetailView: View {
    @Binding var template: WorkoutTemplate
    @State private var newExercise: String = ""

    private let days = ["None", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        Form {
            Section(header: Text("Template")) {
                TextField("Template name", text: $template.name)
            }

            Section(header: HStack {
                Text("Exercises")
                Spacer()
            }) {
                if template.exercises.isEmpty {
                    Text("No exercises yet. Add one below.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(template.exercises.indices, id: \.self) { i in
                        HStack {
                            Text(template.exercises[i])
                            Spacer()
                        }
                    }
                    .onDelete { idxSet in
                        template.exercises.remove(atOffsets: idxSet)
                    }
                }

                HStack {
                    TextField("Add exercise (e.g. Bench Press)", text: $newExercise)
                    Button(action: addExercise) {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                    .disabled(newExercise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(header: Text("Assign to day")) {
                Picker("Assigned Day", selection: Binding(
                    get: { template.assignedDay ?? "None" },
                    set: { newValue in
                        template.assignedDay = (newValue == "None") ? nil : newValue
                    }
                )) {
                    ForEach(days, id: \.self) { day in
                        Text(day).tag(day)
                    }
                }
            }

            Section {
                Button("Save (returns)") {
                    // Changes already bound. Just pop view — handled by NavigationLink parent.
                    // No explicit action required here.
                    hideKeyboard()
                }
            }
        }
        .navigationTitle(template.name.isEmpty ? "Template" : template.name)
    }

    private func addExercise() {
        let trimmed = newExercise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        template.exercises.append(trimmed)
        newExercise = ""
        hideKeyboard()
    }
}

// small utility to dismiss keyboard
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

// MARK: - Preview
struct WorkoutTemplateView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutTemplateView()
    }
}
