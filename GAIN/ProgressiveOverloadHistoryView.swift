import SwiftUI
import Charts

struct ProgressiveOverloadHistoryView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var overloadSettings: ProgressiveOverloadSettingsStore
    
    @State private var selectedExercise: String = ""
    @State private var selectedMetric: Metric = .weight
    @State private var currentIncrement: Double = 2.5
    @State private var selectedCategory: ProgressiveOverloadSettingsStore.ProgressionCategory? = nil
    @State private var minIncrement: Double = 0.5
    @State private var maxIncrement: Double = 5.0
    @State private var deloadEveryWeeks: Int = 5
    @State private var repRangeLower: Int = 6
    @State private var repRangeUpper: Int = 12
    
    enum Metric: String, CaseIterable, Identifiable {
        case weight = "Weight"
        case sets = "Sets"
        case volume = "Volume"
        var id: String { rawValue }
    }
    
    struct OverloadSample: Identifiable {
        let id = UUID()
        let date: Date
        let bestWeight: Double
        let totalSets: Int
        let volume: Double
    }
    
    private var exerciseNames: [String] {
        var names = Set<String>()
        for record in workoutStore.records where !record.isUnfinished {
            for ex in record.exercises {
                names.insert(ex.name)
            }
        }
        return Array(names).sorted()
    }
    
    private var samples: [OverloadSample] {
        guard !selectedExercise.isEmpty else { return [] }
        let finished = workoutStore.records.filter { !$0.isUnfinished }
        var result: [OverloadSample] = []
        
        for record in finished.sorted(by: { $0.start < $1.start }) {
            guard let ex = record.exercises.first(where: { $0.name == selectedExercise }) else { continue }
            let bestWeight = ex.sets.map { $0.weight }.max() ?? 0
            let totalSets = ex.sets.count
            let volume = ex.sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            guard bestWeight > 0 || totalSets > 0 || volume > 0 else { continue }
            result.append(OverloadSample(date: record.start, bestWeight: bestWeight, totalSets: totalSets, volume: volume))
        }
        return result
    }
    
    var body: some View {
        List {
            Section {
                if exerciseNames.isEmpty {
                    Text("No exercises found yet.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(exerciseNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(Metric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            Section("Progression") {
                if samples.isEmpty {
                    Text("No data for this exercise yet.")
                        .foregroundColor(.secondary)
                } else {
                    Chart {
                        ForEach(samples) { sample in
                            switch selectedMetric {
                            case .weight:
                                LineMark(
                                    x: .value("Date", sample.date, unit: .day),
                                    y: .value("Weight", sample.bestWeight)
                                )
                                .symbol(Circle())
                                .foregroundStyle(.teal)
                            case .sets:
                                BarMark(
                                    x: .value("Date", sample.date, unit: .day),
                                    y: .value("Sets", sample.totalSets)
                                )
                                .foregroundStyle(.orange)
                            case .volume:
                                LineMark(
                                    x: .value("Date", sample.date, unit: .day),
                                    y: .value("Volume", sample.volume)
                                )
                                .symbol(Circle())
                                .foregroundStyle(.purple)
                            }
                        }
                    }
                    .frame(height: 240)
                }
            }
            
            Section("Overload Settings") {
                if selectedExercise.isEmpty {
                    Text("Select an exercise to configure overload settings.")
                        .foregroundColor(.secondary)
                } else {
                    Picker("Category", selection: Binding(
                        get: { selectedCategory ?? overloadSettings.category(for: selectedExercise) },
                        set: { newValue in
                            selectedCategory = newValue
                            overloadSettings.setCategory(newValue, for: selectedExercise)
                            if let category = newValue {
                                overloadSettings.applyDefaultProfile(for: category, exerciseName: selectedExercise)
                                syncUIFromStore(for: selectedExercise)
                            }
                        }
                    )) {
                        Text("Custom").tag(Optional<ProgressiveOverloadSettingsStore.ProgressionCategory>.none)
                        ForEach(ProgressiveOverloadSettingsStore.ProgressionCategory.allCases, id: \.self) { c in
                            Text(categoryLabel(c)).tag(Optional(c))
                        }
                    }
                    .pickerStyle(.menu)

                    Stepper(value: $currentIncrement, in: 0.5...20, step: 0.5) {
                        Text(String(format: "Weight increment: %.1f kg", currentIncrement))
                    }
                    .onChange(of: currentIncrement) { _, newValue in
                        overloadSettings.setIncrement(newValue, for: selectedExercise)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rep Range")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Stepper(value: $repRangeLower, in: 1...repRangeUpper, step: 1) {
                                Text("Min: \(repRangeLower)")
                            }
                        }
                        HStack {
                            Stepper(value: $repRangeUpper, in: repRangeLower...30, step: 1) {
                                Text("Max: \(repRangeUpper)")
                            }
                        }
                    }
                    .onChange(of: repRangeLower) { _, _ in
                        overloadSettings.setTargetRepsPerSet(repRangeLower...repRangeUpper, for: selectedExercise)
                    }
                    .onChange(of: repRangeUpper) { _, _ in
                        overloadSettings.setTargetRepsPerSet(repRangeLower...repRangeUpper, for: selectedExercise)
                    }

                    Stepper(value: $minIncrement, in: 0.5...maxIncrement, step: 0.5) {
                        Text(String(format: "Min increment: %.1f kg", minIncrement))
                    }
                    .onChange(of: minIncrement) { _, newValue in
                        overloadSettings.setMinIncrementKg(newValue, for: selectedExercise)
                    }

                    Stepper(value: $maxIncrement, in: minIncrement...20, step: 0.5) {
                        Text(String(format: "Max increment: %.1f kg", maxIncrement))
                    }
                    .onChange(of: maxIncrement) { _, newValue in
                        overloadSettings.setMaxIncrementKg(newValue, for: selectedExercise)
                    }

                    Stepper(value: $deloadEveryWeeks, in: 3...12, step: 1) {
                        Text("Deload every: \(deloadEveryWeeks) weeks")
                    }
                    .onChange(of: deloadEveryWeeks) { _, newValue in
                        overloadSettings.setDeloadEveryWeeks(newValue, for: selectedExercise)
                    }
                    
                    Text("These settings are used to adjust the 'Next' suggestion for this exercise in live workouts.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Progressive Overload")
        .onAppear {
            if selectedExercise.isEmpty, let first = exerciseNames.first {
                selectedExercise = first
            }
            if !selectedExercise.isEmpty {
                currentIncrement = overloadSettings.increment(for: selectedExercise)
                syncUIFromStore(for: selectedExercise)
            }
        }
        .onChange(of: selectedExercise) { _, newValue in
            if !newValue.isEmpty {
                currentIncrement = overloadSettings.increment(for: newValue)
                syncUIFromStore(for: newValue)
            }
        }
    }

    private func syncUIFromStore(for exerciseName: String) {
        selectedCategory = overloadSettings.category(for: exerciseName)

        if let rr = overloadSettings.targetRepsPerSet(for: exerciseName) {
            repRangeLower = rr.lowerBound
            repRangeUpper = rr.upperBound
        } else {
            repRangeLower = 6
            repRangeUpper = 12
        }

        if let minInc = overloadSettings.minIncrementKg(for: exerciseName) {
            minIncrement = minInc
        } else {
            minIncrement = 0.5
        }

        if let maxInc = overloadSettings.maxIncrementKg(for: exerciseName) {
            maxIncrement = maxInc
        } else {
            maxIncrement = max(minIncrement, 5.0)
        }

        if let deload = overloadSettings.deloadEveryWeeks(for: exerciseName) {
            deloadEveryWeeks = deload
        } else {
            deloadEveryWeeks = 5
        }

        if maxIncrement < minIncrement {
            maxIncrement = minIncrement
        }
        if repRangeUpper < repRangeLower {
            repRangeUpper = repRangeLower
        }
    }

    private func categoryLabel(_ category: ProgressiveOverloadSettingsStore.ProgressionCategory) -> String {
        switch category {
        case .strengthDominant:
            return "Strength"
        case .hypertrophy:
            return "Hypertrophy"
        case .endurance:
            return "Endurance"
        }
    }
}

#Preview {
    NavigationStack {
        ProgressiveOverloadHistoryView()
            .environmentObject(WorkoutStore.preview)
            .environmentObject(ProgressiveOverloadSettingsStore())
    }
}
