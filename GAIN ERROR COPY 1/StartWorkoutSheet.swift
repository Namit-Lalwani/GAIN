import SwiftUI

// MARK: - Start Workout Sheet
struct StartWorkoutSheet: View {
    @EnvironmentObject var routineStore: RoutineStore
    @EnvironmentObject var templateStore: TemplateStore
    @Environment(\.presentationMode) var presentationMode
    @State private var showWorkoutSession = false
    @State private var selectedTemplate: WorkoutTemplate? = nil

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Today's assigned")) {
                    Text(routineStore.templateFor(date: Date()))
                }

                Section {
                    Button("Start Today's Routine") {
                        let todayTemplateName = routineStore.templateFor(date: Date())
                        if todayTemplateName != "Rest" {
                            // Find template by name
                            if let template = templateStore.templates.first(where: { $0.name == todayTemplateName }) {
                                selectedTemplate = WorkoutTemplate(
                                    name: template.name,
                                    exercises: template.exercises.map { $0.name }
                                )
                            }
                        }
                        presentationMode.wrappedValue.dismiss()
                        showWorkoutSession = true
                    }

                    Button("Start Empty Workout") {
                        selectedTemplate = nil
                        presentationMode.wrappedValue.dismiss()
                        showWorkoutSession = true
                    }

                    NavigationLink("Start From Template") {
                        TemplatePickerView(onSelect: { templateName in
                            selectedTemplate = WorkoutTemplate(name: templateName, exercises: [])
                            showWorkoutSession = true
                        })
                    }
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showWorkoutSession) {
            NavigationView {
                if let template = selectedTemplate {
                    WorkoutSessionView(template: template)
                } else {
                    WorkoutSessionView()
                }
            }
        }
    }
}

// MARK: - Template Picker
struct TemplatePickerView: View {
    @EnvironmentObject var templateStore: TemplateStore
    @Environment(\.presentationMode) var presentationMode
    var onSelect: (String) -> Void
    
    var body: some View {
        List {
            Section(header: Text("Saved Templates")) {
                ForEach(templateStore.templates) { template in
                    Button(action: {
                        onSelect(template.name)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(template.name)
                            Spacer()
                        }
                    }
                }
            }
            
            Section(header: Text("Quick Templates")) {
                ForEach(["Push", "Pull", "Legs", "Upper", "Accessory", "Custom"], id: \.self) { name in
                    Button(action: {
                        onSelect(name)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Text(name)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Choose Template")
    }
}

// MARK: - Today Summary
struct TodaySummaryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Today's Summary")
                    .font(.title2).bold()

                Text("Quick stats will appear here.")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
        }
    }
}

