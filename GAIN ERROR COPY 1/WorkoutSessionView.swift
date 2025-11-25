// WorkoutSessionView.swift
import SwiftUI

struct WorkoutSessionView: View {
    // Use shared store singleton (make sure App supplies env if you're using @EnvironmentObject elsewhere)
    @ObservedObject private var store: WorkoutStore = .shared
    
    let template: WorkoutTemplate?

    // Local "live" workout record while session is in progress.
    @State private var current: WorkoutRecord
    
    @State private var startTime = Date()
    @State private var isCompleted = false
    
    init(template: WorkoutTemplate? = nil) {
        self.template = template
        let templateName = template?.name ?? "Custom Workout"
        let exercises = template?.exercises.map { exerciseName in
            WorkoutExerciseRecord(name: exerciseName, sets: [])
        } ?? []
        _current = State(initialValue: WorkoutRecord(
            templateName: templateName,
            exercises: exercises
        ))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(current.templateName ?? "Custom Workout")
                        .font(.headline)
                    Text(startTime, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: endWorkout) {
                    Text("End Workout")
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach($current.exercises) { $exercise in
                        DisclosureGroup(isExpanded: .constant(true)) {
                            VStack(spacing: 8) {
                                ForEach($exercise.sets) { $set in
                                    HStack(spacing: 12) {
                                        TextField("Reps", value: $set.reps, format: .number)
                                            .keyboardType(.numberPad)
                                            .frame(width: 60)
                                            .textFieldStyle(.roundedBorder)

                                        TextField("Weight", value: $set.weight, format: .number)
                                            .keyboardType(.decimalPad)
                                            .frame(width: 80)
                                            .textFieldStyle(.roundedBorder)

                                        TextField("Note", text: Binding($set.note, replacingNilWith: ""))
                                            .textFieldStyle(.roundedBorder)

                                        Button(action: {
                                            set.completedAt = set.completedAt == nil ? Date() : nil
                                        }) {
                                            Image(systemName: set.completedAt == nil ? "circle" : "checkmark.circle.fill")
                                        }
                                    }
                                }

                                HStack {
                                    Button("Add Set") {
                                        exercise.sets.append(WorkoutSetRecord())
                                    }
                                    .buttonStyle(.bordered)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 8)
                        } label: {
                            Text(exercise.name).font(.headline)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).stroke())
                    }
                }
                .padding()
            }

            Spacer()
        }
        .navigationTitle("Live Workout")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveNow() }
            }
        }
    }

    // MARK: - Actions

    private func endWorkout() {
        // Estimate duration
        let duration = Date().timeIntervalSince(startTime)
        current.duration = duration
        isCompleted = true
    }

    private func saveNow() {
        // Update start if not set
        current.start = startTime
        // Update end and duration
        let now = Date()
        current.end = now
        current.duration = now.timeIntervalSince(startTime)
        // Save into store
        store.add(current)
        // Start fresh for next session
        current = WorkoutRecord(templateName: "Custom Workout", start: Date(), exercises: [])
        startTime = Date()
        isCompleted = false
    }
}

// Helper to bind optional String to TextField
fileprivate extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(get: { source.wrappedValue ?? fallback },
                  set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue })
    }
}

// Small preview
struct WorkoutSessionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WorkoutSessionView()
        }
    }
}
