import SwiftUI

struct TemplateEditorView: View {
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var exerciseLibrary: ExerciseLibraryStore
    @ObservedObject private var scheduleManager = RoutineScheduleManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State var template: TemplateModel
    @State private var showLibrary = false
    @State private var selectedWeekday: Weekday? = nil
    
    init(template: TemplateModel) {
        _template = State(initialValue: template)
    }

    var body: some View {
        Form {
            Section(header: Text("Routine Name")) {
                TextField("Routine name", text: $template.name)
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

                Button(action: { showLibrary = true }) {
                    Label("Add Exercise", systemImage: "plus")
                }
            }

            Section(header: Text("Schedule")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick assign to day:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Weekday.allCases) { weekday in
                                let isAssigned = scheduleManager.templateId(for: weekday) == template.id
                                Button {
                                    if isAssigned {
                                        scheduleManager.setTemplate(for: weekday, templateId: nil)
                                    } else {
                                        scheduleManager.setTemplate(for: weekday, templateId: template.id)
                                    }
                                } label: {
                                    Text(weekday.shortName)
                                        .font(.caption)
                                        .fontWeight(isAssigned ? .bold : .regular)
                                        .foregroundColor(isAssigned ? .white : .primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isAssigned ? Color.blue : Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Text("Tap a day to toggle assignment. Go to Templates → Edit to manage full schedule.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Button("Save Routine") {
                    saveTemplate()
                }
                .font(.headline)
                
                if templateStore.templates.contains(where: { $0.id == template.id }) {
                    Button(role: .destructive) {
                        deleteTemplate()
                    } label: {
                        Text("Delete Routine")
                    }
                }
            }
        }
        .navigationTitle(template.name.isEmpty ? "New Routine" : template.name)
        .sheet(isPresented: $showLibrary) {
            NavigationView {
                ExerciseLibraryView { definition in
                    var new = Exercise(name: definition.name, sets: [])
                    if let primaries = definition.primaryMuscles, !primaries.isEmpty {
                        new.muscleGroups = primaries.map { $0.lowercased() }
                    }
                    template.exercises.append(new)
                }
                .environmentObject(exerciseLibrary)
            }
        }
    }

    private func saveTemplate() {
        if let i = templateStore.templates.firstIndex(where: { $0.id == template.id }) {
            templateStore.templates[i] = template
        } else {
            templateStore.add(template)
        }
        presentationMode.wrappedValue.dismiss()
    }

    private func deleteTemplate() {
        // Also remove from any scheduled days
        for weekday in Weekday.allCases {
            if scheduleManager.templateId(for: weekday) == template.id {
                scheduleManager.setTemplate(for: weekday, templateId: nil)
            }
        }
        
        if let index = templateStore.templates.firstIndex(where: { $0.id == template.id }) {
            templateStore.templates.remove(at: index)
        }
        presentationMode.wrappedValue.dismiss()
    }
}
