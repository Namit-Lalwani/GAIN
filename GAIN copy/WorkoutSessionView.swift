import SwiftUI

// Local models for in-session use
struct WorkoutExercise: Identifiable {
    let id = UUID()
    var name: String
    var isExpanded: Bool = true
    var sets: [WorkoutSet] = [WorkoutSet()]
}

struct WorkoutSet: Identifiable {
    let id = UUID()
    var reps: Int = 0
    var weight: Double = 0
    var note: String = ""
    var isCompleted: Bool = false

    // per-set metadata captured at completion
    var completedAt: Date?
    var heartRateAtCompletion: Double?
}

struct WorkoutSessionView: View {
    var template: WorkoutTemplate?

    @State private var startTime = Date()
    @State private var currentTime = Date()
    @State private var timer: Timer? = nil
    @State private var isCompleted = false

    @State private var exercises: [WorkoutExercise]

    // summary flow
    @State private var showSummary = false
    @State private var lastSummary: WorkoutSummary? = nil

    // Reference to HealthKit manager for current HR
    @ObservedObject private var hk = HealthKitManager.shared

    init(template: WorkoutTemplate? = nil) {
        self.template = template
        let initial: [WorkoutExercise]
        if let t = template {
            initial = t.exercises.map { WorkoutExercise(name: $0) }
        } else {
            initial = [WorkoutExercise(name: "Bench Press"), WorkoutExercise(name: "Squat")]
        }
        _exercises = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 12) {
            headerView
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($exercises) { $exercise in
                        DisclosureGroup(isExpanded: $exercise.isExpanded) {
                            VStack(spacing: 8) {
                                ForEach($exercise.sets) { $set in
                                    setRow(set: set, parentExercise: $exercise)
                                }
                                HStack {
                                    Spacer()
                                    Button {
                                        exercise.sets.append(WorkoutSet())
                                    } label: { Label("Add Set", systemImage: "plus.circle") }
                                    .buttonStyle(.borderedProminent)
                                }
                            }.padding(.vertical, 6)
                        } label: {
                            HStack {
                                Text(exercise.name).font(.headline)
                                Spacer()
                                Text("\(exercise.sets.count) sets").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).stroke())
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { stopTimer() }
        .sheet(isPresented: $showSummary) {
            if let summary = lastSummary {
                WorkoutSummaryView(summary: summary) { shouldSave in
                    if shouldSave {
                        // build ExerciseRecord & SetRecord then save
                        let exerciseRecords: [ExerciseRecord] = exercises.map { ex in
                            let setRecords: [SetRecord] = ex.sets.map { s in
                                SetRecord(reps: s.reps,
                                          weight: s.weight,
                                          note: s.note,
                                          isCompleted: s.isCompleted,
                                          completedAt: s.completedAt,
                                          heartRateAtCompletion: s.heartRateAtCompletion)
                            }
                            return ExerciseRecord(name: ex.name, sets: setRecords)
                        }
                        // call store
                        WorkoutStore.shared.addWorkout(templateName: template?.name, start: summary.start, end: summary.end, exercises: exerciseRecords, notes: nil)
                    }
                    showSummary = false
                }
            } else {
                Text("Summary unavailable")
            }
        }
        .navigationTitle(template?.name ?? "Live Workout")
    }

    // MARK: header and timer
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Started: \(startTime.formatted(date: .omitted, time: .shortened))").font(.caption)
                Text("Duration: \(formatTimeInterval(currentTime.timeIntervalSince(startTime)))").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: endOrRestart) {
                Text(isCompleted ? "Restart" : "End Workout")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }

    // MARK: set row with HR capture
    @ViewBuilder
    private func setRow(set: Binding<WorkoutSet>, parentExercise: Binding<WorkoutExercise>) -> some View {
        HStack(spacing: 12) {
            TextField("Reps", value: set.reps, format: .number)
                .keyboardType(.numberPad)
                .frame(width: 60)
                .textFieldStyle(.roundedBorder)

            TextField("Weight", value: set.weight, format: .number)
                .keyboardType(.decimalPad)
                .frame(width: 80)
                .textFieldStyle(.roundedBorder)

            TextField("Note", text: set.note)
                .textFieldStyle(.roundedBorder)

            Button(action: {
                // toggle completion and capture HR & timestamp if marking completed
                let currentlyCompleted = set.isCompleted.wrappedValue
                set.isCompleted.wrappedValue.toggle()
                if !currentlyCompleted && set.isCompleted.wrappedValue {
                    // just completed — record HR & timestamp
                    set.completedAt.wrappedValue = Date()
                    set.heartRateAtCompletion.wrappedValue = hk.heartRate // current value from HealthKitManager
                } else if currentlyCompleted && !set.isCompleted.wrappedValue {
                    // unset completion — clear metadata
                    set.completedAt.wrappedValue = nil
                    set.heartRateAtCompletion.wrappedValue = nil
                }
            }) {
                Image(systemName: set.isCompleted.wrappedValue ? "checkmark.circle.fill" : "circle")
            }
        }
    }

    // MARK: timer handling
    private func startTimer() {
        startTime = Date()
        currentTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func endOrRestart() {
        if isCompleted {
            // restart
            isCompleted = false
            startTimer()
        } else {
            // end and compute summary
            stopTimer()
            isCompleted = true

            let end = Date()
            let duration = end.timeIntervalSince(startTime)

            var totalSets = 0
            var totalReps = 0
            var totalVolume: Double = 0
            var exSummaries: [ExerciseSummary] = []

            for ex in exercises {
                var sCount = 0
                var sReps = 0
                var sVol: Double = 0
                for s in ex.sets {
                    sCount += 1
                    sReps += s.reps
                    sVol += Double(s.reps) * s.weight
                }
                totalSets += sCount
                totalReps += sReps
                totalVolume += sVol
                exSummaries.append(ExerciseSummary(name: ex.name, sets: sCount, reps: sReps, volume: sVol))
            }

            let summary = WorkoutSummary(templateName: template?.name, start: startTime, end: end, duration: duration, totalSets: totalSets, totalReps: totalReps, totalVolume: totalVolume, exercises: exSummaries)

            lastSummary = summary
            showSummary = true
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: lightweight summary types (shared with WorkoutSummaryView)
struct ExerciseSummary: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: Int
    let volume: Double
}

struct WorkoutSummary {
    let templateName: String?
    let start: Date
    let end: Date
    let duration: TimeInterval
    let totalSets: Int
    let totalReps: Int
    let totalVolume: Double
    let exercises: [ExerciseSummary]
}

// Preview
#Preview {
    let t = WorkoutTemplate(id: UUID(), name: "Mock", exercises: ["Bench", "Squat"])
    NavigationStack { WorkoutSessionView(template: t) }
}
