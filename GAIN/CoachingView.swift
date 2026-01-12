// CoachingView.swift
import SwiftUI

struct CoachingView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var selectedGoal: TrainingGoal = .hypertrophy
    @State private var selectedExperience: ExperienceLevel = .intermediate
    @State private var selectedExerciseName: String?
    @State private var recommendation: WorkoutRecommendation?
    @State private var customWeight: String = ""
    @State private var customReps: String = ""
    @State private var customSets: String = ""
    @State private var customRest: String = ""
    @State private var useCustom: Bool = false

    // Extract unique exercise names from history
    private var exerciseNames: [String] {
        let names = Set(workoutStore.records.flatMap { $0.exercises.map { $0.name } })
        return names.sorted()
    }

    // Find the latest set for the selected exercise
    private var latestSet: (weight: Double, reps: Int)? {
        guard let name = selectedExerciseName else { return nil }
        let relevant = workoutStore.records
            .sorted { $0.start > $1.start }
            .compactMap { w in w.exercises.first { $0.name == name } }
        guard let lastExercise = relevant.first else { return nil }
        // Pick the set with highest estimated 1RM as "best" set
        let best = lastExercise.sets.max { s1, s2 in
            let est1 = OneRepMaxCalculator.estimatedOneRM(weight: s1.weight, reps: s1.reps)
            let est2 = OneRepMaxCalculator.estimatedOneRM(weight: s2.weight, reps: s2.reps)
            return est1 < est2
        }
        return best.map { ($0.weight, $0.reps) }
    }

    // Compute estimated 1RM for the selected exercise
    private var estimated1RM: Double? {
        guard let name = selectedExerciseName else { return nil }
        return StrengthAnalytics.bestOneRM(for: name, workouts: workoutStore.records)
    }

    var body: some View {
        List {
            // Goal picker
            Section("Training Goal") {
                Picker("Goal", selection: $selectedGoal) {
                    ForEach(TrainingGoal.allCases, id: \.self) { goal in
                        Text(goal.rawValue.capitalized).tag(goal)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Experience picker
            Section("Experience Level") {
                Picker("Experience", selection: $selectedExperience) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { exp in
                        Text(exp.rawValue.capitalized).tag(exp)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Exercise picker
            Section("Exercise") {
                if exerciseNames.isEmpty {
                    Text("No exercises logged yet").foregroundColor(.secondary)
                } else {
                    Picker("Exercise", selection: $selectedExerciseName) {
                        Text("Select an exercise").tag(nil as String?)
                        ForEach(exerciseNames, id: \.self) { name in
                            Text(name).tag(name as String?)
                        }
                    }
                }
            }

            // Compute button
            Section {
                Button(action: computeRecommendation) {
                    Text("Generate Recommendation")
                        .frame(maxWidth: .infinity)
                }
                .disabled(selectedExerciseName == nil)
            }

            // Show recommendation
            if let rec = recommendation {
                Section("Recommendation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sets: \(rec.sets)")
                        Text("Reps: \(rec.reps)")
                        Text("Weight: \(rec.targetWeight, specifier: "%.1f") kg")
                        Text("Rest: \(rec.restSeconds) s")
                        Text("Confidence: \(Int(rec.confidence * 100))%")
                            .foregroundColor(rec.confidence > 0.8 ? .green : rec.confidence > 0.6 ? .orange : .red)
                        Text("Reason: \(rec.reason)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Custom overrides
                Section("Custom Overrides (optional)") {
                    Toggle("Use custom values", isOn: $useCustom)
                    if useCustom {
                        HStack {
                            Text("Weight (kg)")
                            TextField("kg", text: $customWeight)
                                .keyboardType(.decimalPad)
                        }
                        HStack {
                            Text("Reps")
                            TextField("reps", text: $customReps)
                                .keyboardType(.numberPad)
                        }
                        HStack {
                            Text("Sets")
                            TextField("sets", text: $customSets)
                                .keyboardType(.numberPad)
                        }
                        HStack {
                            Text("Rest (s)")
                            TextField("seconds", text: $customRest)
                                .keyboardType(.numberPad)
                        }
                    }
                }
            }
        }
        .navigationTitle("Coaching")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if recommendation != nil && useCustom {
                    Button("Apply Custom") {
                        applyCustom()
                    }
                }
            }
        }
    }

    private func computeRecommendation() {
        guard let name = selectedExerciseName else { return }

        // Default to compound if not known
        let exerciseType: ExerciseType = ["Squat", "Bench Press", "Deadlift", "Overhead Press"].contains(name) ? .compound : .accessory

        let weight = latestSet?.weight ?? 0
        let reps = latestSet?.reps ?? 0
        let oneRM = estimated1RM

        let rec = AdvancedProgressionEngine.suggestNextSession(
            exerciseName: name,
            exerciseType: exerciseType,
            lastWeight: weight,
            lastReps: reps,
            estimated1RM: oneRM,
            goal: selectedGoal,
            experience: selectedExperience
        )
        self.recommendation = rec

        // Pre‑fill custom fields with recommendation
        customWeight = String(format: "%.1f", rec.targetWeight)
        customReps = String(rec.reps)
        customSets = String(rec.sets)
        customRest = String(rec.restSeconds)
    }

    private func applyCustom() {
        // This is where you would apply the custom values to your session/template.
        // For now we just print a message.
        print("Applied custom: \(customWeight) kg, \(customReps) reps, \(customSets) sets, \(customRest) s")
    }
}

#Preview {
    NavigationStack {
        CoachingView()
            .environmentObject(WorkoutStore.preview)
    }
}
