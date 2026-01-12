// WorkoutSessionView.swift
import SwiftUI
import Combine

struct WorkoutSessionView: View {
    @ObservedObject private var store: WorkoutStore = .shared
    @EnvironmentObject var exerciseLibrary: ExerciseLibraryStore
    @EnvironmentObject var overloadSettings: ProgressiveOverloadSettingsStore
    @EnvironmentObject var weightStore: WeightStore
    @Environment(\.dismiss) private var dismiss
    
    let template: WorkoutTemplate?

    // Local "live" workout record while session is in progress
    @State private var current: WorkoutRecord
    @State private var startTime = Date()
    
    // Timer states
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerActive = true
    
    // Rest timer
    @State private var restTimeRemaining: Int = 0
    @State private var isResting = false
    @State private var defaultRestSeconds: Int = 90
    @State private var restEndTime: Date?
    
    // UI states
    @State private var showEndConfirmation = false
    @State private var showAddExercise = false
    @State private var newExerciseName = ""
    @State private var expandedExercises: Set<UUID> = []
    @State private var showPlateCalculator = false
    @State private var plateCalcWeight: Double = 0
    @FocusState private var isInputFocused: Bool
    @State private var weightTextBySet: [UUID: String] = [:]
    @State private var repsTextBySet: [UUID: String] = [:]
    @State private var rpeTextBySet: [UUID: String] = [:]
    @State private var rirTextBySet: [UUID: String] = [:]
    @State private var showNextSuggestionLine: Bool = true

    // Bodyweight logging in-session
    @State private var showLogBodyWeight: Bool = false
    @State private var bodyWeightText: String = ""
    @State private var bodyWeightDate: Date = Date()
    
    // Timer publisher
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(template: WorkoutTemplate? = nil) {
        self.template = template
        let templateName = template?.name ?? "Custom Routine"
        let exercises = template?.exercises.map { exerciseName in
            WorkoutExerciseRecord(name: exerciseName, sets: [
                WorkoutSetRecord(reps: 0, weight: 0)
            ])
        } ?? []
        _current = State(initialValue: WorkoutRecord(
            templateName: templateName,
            exercises: exercises
        ))
        _expandedExercises = State(initialValue: Set(exercises.map { $0.id }))
    }

    init(record: WorkoutRecord) {
        self.template = nil
        _current = State(initialValue: record)
        _expandedExercises = State(initialValue: Set(record.exercises.map { $0.id }))
    }

    var body: some View {
        VStack(spacing: 0) {
                // MARK: - Header Stats Bar
                headerStatsBar
                
                // MARK: - Rest Timer Banner (when active)
                if isResting {
                    restTimerBanner
                }
                
                // MARK: - Exercise List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach($current.exercises) { $exercise in
                            exerciseCard(exercise: $exercise)
                        }
                        
                        // Add Exercise Button
                        addExerciseButton

                        // Session Notes
                        sessionNotesSection
                    }
                    .padding()
                }
                
            // MARK: - Bottom Action Bar
            bottomActionBar
        }
        .background(Color.gainBackground)
        .navigationTitle("Live Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    showEndConfirmation = true
                }
                .foregroundColor(.red)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        timerActive.toggle()
                    } label: {
                        Label(timerActive ? "Pause Timer" : "Resume Timer",
                              systemImage: timerActive ? "pause.circle" : "play.circle")
                    }
                    
                    Button {
                        showPlateCalculator = true
                    } label: {
                        Label("Plate Calculator", systemImage: "scale.3d")
                    }

                    Button {
                        showNextSuggestionLine.toggle()
                    } label: {
                        Label(showNextSuggestionLine ? "Hide Next Suggestion" : "Show Next Suggestion",
                              systemImage: showNextSuggestionLine ? "eye.slash" : "eye")
                    }

                    Button {
                        openBodyWeightLogger()
                    } label: {
                        Label("Log Body Weight", systemImage: "figure")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputFocused = false
                }
            }
        }
        .onReceive(timer) { _ in
            if timerActive {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
            if isResting, let endTime = restEndTime {
                let remaining = Int(max(0, endTime.timeIntervalSinceNow.rounded(.up)))
                restTimeRemaining = remaining
                if remaining <= 0 {
                    isResting = false
                    restEndTime = nil
                    // Haptic & sound when rest ends
                    let notification = UINotificationFeedbackGenerator()
                    notification.notificationOccurred(.success)
                }
            }
        }
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Save & End") {
                saveAndEnd()
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("Do you want to save this session or discard it?")
        }
        .sheet(isPresented: $showAddExercise) {
            addExerciseSheet
        }
        .sheet(isPresented: $showPlateCalculator) {
            PlateCalculatorView(targetWeight: $plateCalcWeight)
        }
        .sheet(isPresented: $showLogBodyWeight) {
            logBodyWeightSheet
        }
    }
    
    // MARK: - Header Stats Bar
    private var headerStatsBar: some View {
        HStack(spacing: 0) {
            // Elapsed Time
            VStack(spacing: 2) {
                Text(formatTime(elapsedTime))
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                Text("Elapsed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Volume
            VStack(spacing: 2) {
                Text("\(Int(current.totalVolume)) kg")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Volume")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sets & Reps
            VStack(spacing: 2) {
                Text("\(current.totalSets) / \(current.totalReps)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Sets / Reps")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: openBodyWeightLogger) {
                Image(systemName: "figure")
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.gainCardSoft.opacity(0.9))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.gainCardSoft)
        .cornerRadius(12)
    }
    
    // MARK: - Rest Timer Banner
    private var restTimerBanner: some View {
        HStack {
            Image(systemName: "timer")
                .font(.title3)
            Text("Rest: \(formatRestTime(restTimeRemaining))")
                .font(.headline)
            Spacer()
            
            // Quick adjust buttons
            Button {
                let newRemaining = max(0, restTimeRemaining - 15)
                restTimeRemaining = newRemaining
                if let endTime = restEndTime {
                    restEndTime = endTime.addingTimeInterval(-15)
                } else if isResting {
                    restEndTime = Date().addingTimeInterval(TimeInterval(newRemaining))
                }
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
            }
            
            Button {
                restTimeRemaining += 15
                if let endTime = restEndTime {
                    restEndTime = endTime.addingTimeInterval(15)
                } else if isResting {
                    restEndTime = Date().addingTimeInterval(TimeInterval(restTimeRemaining))
                }
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            
            Button("Skip") {
                isResting = false
                restTimeRemaining = 0
                restEndTime = nil
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .background(
            LinearGradient(
                colors: restTimeRemaining <= 10 ? [Color.orange, Color.red] : [Color.gainPrimary, Color.gainAccent],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .foregroundColor(.white)
    }
    
    // MARK: - Exercise Card
    private func exerciseCard(exercise: Binding<WorkoutExerciseRecord>) -> some View {
        VStack(spacing: 0) {
            // Exercise Header
            Button {
                let exerciseId = exercise.id
                withAnimation {
                    if expandedExercises.contains(exerciseId) {
                        expandedExercises.remove(exerciseId)
                    } else {
                        expandedExercises.insert(exerciseId)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.wrappedValue.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Compact performance summary line: Last · PR · Next
                        let lastText = previousPerformance(for: exercise.wrappedValue.name).map { "Last \($0)" }
                        let prText: String? = {
                            if let pr = bestSet(for: exercise.wrappedValue.name) {
                                return "PR \(Int(pr.weight))kg × \(pr.reps)"
                            }
                            return nil
                        }()
                        let nextText: String? = showNextSuggestionLine ? nextPlanSummary(for: exercise.wrappedValue.name).map { "Next \($0)" } : nil
                        let parts = [lastText, prText, nextText].compactMap { $0 }
                        if !parts.isEmpty {
                            Text(parts.joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Optional exercise notes
                        if let notes = exercise.wrappedValue.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    // Completion indicator
                    let completed = exercise.wrappedValue.sets.filter { $0.completedAt != nil }.count
                    let total = exercise.wrappedValue.sets.count
                    Text("\(completed)/\(total)")
                        .font(.subheadline)
                        .foregroundColor(completed == total && total > 0 ? .green : .secondary)
                    
                    Image(systemName: expandedExercises.contains(exercise.id) ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gainCard)
            }
            
            // Sets (when expanded)
            if expandedExercises.contains(exercise.id) {
                VStack(spacing: 0) {
                    // Exercise notes editor
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exercise Notes")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                        TextField("Notes for this exercise", text: Binding(exercise.notes, replacingNilWith: ""))
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: exercise.wrappedValue.notes ?? "") { _, _ in
                                persistDraft()
                            }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Header row
                    HStack {
                        Text("SET")
                            .frame(width: 40)
                        Text("PREV")
                            .frame(width: 70)
                        Text("KG")
                            .frame(width: 70)
                        Text("REPS")
                            .frame(width: 60)
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    ForEach(exercise.wrappedValue.sets.indices, id: \.self) { index in
                        setRow(
                            setNumber: index + 1,
                            set: exercise.sets[index],
                            exerciseName: exercise.wrappedValue.name,
                            onDelete: {
                                exercise.wrappedValue.sets.remove(at: index)
                                persistDraft()
                            },
                            onValueChange: { newReps, newWeight in
                                // Propagate edited reps/weight to later, not-completed sets
                                let totalSets = exercise.wrappedValue.sets.count
                                guard index + 1 < totalSets else { return }
                                for idx in (index + 1)..<totalSets {
                                    if exercise.wrappedValue.sets[idx].completedAt == nil {
                                        if let reps = newReps {
                                            exercise.wrappedValue.sets[idx].reps = reps
                                        }
                                        if let weight = newWeight {
                                            exercise.wrappedValue.sets[idx].weight = weight
                                        }
                                    }
                                }
                                persistDraft()
                            },
                            onToggleComplete: {
                                // Auto-collapse when all sets are completed
                                let allDone = exercise.wrappedValue.sets.allSatisfy { $0.completedAt != nil }
                                if allDone {
                                    let exerciseId = exercise.id
                                    withAnimation {
                                        _ = expandedExercises.remove(exerciseId)
                                    }
                                }
                                persistDraft()
                            }
                        )
                    }
                    
                    // Add Set Button
                    Button {
                        let previousSet = exercise.wrappedValue.sets.last
                        exercise.wrappedValue.sets.append(WorkoutSetRecord(
                            reps: previousSet?.reps ?? 0,
                            weight: previousSet?.weight ?? 0
                        ))
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Set")
                        }
                        .font(.subheadline)
                        .foregroundColor(.gainAccent)
                    }
                    .padding()
                }
                .background(Color.gainCardSoft)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: - Session Notes
    private var sessionNotesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Session Notes")
                .font(.subheadline).bold()
            TextEditor(text: Binding($current.notes, replacingNilWith: ""))
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .onChange(of: current.notes ?? "") { _, _ in
                    persistDraft()
                }
        }
        .padding()
        .background(Color.gainCard)
        .cornerRadius(12)
    }
    
    // MARK: - Set Row
    private func setRow(setNumber: Int,
                        set: Binding<WorkoutSetRecord>,
                        exerciseName: String,
                        onDelete: @escaping () -> Void,
                        onValueChange: @escaping (_ newReps: Int?, _ newWeight: Double?) -> Void,
                        onToggleComplete: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Set number
                Text("\(setNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 40)
                    .foregroundColor(set.wrappedValue.completedAt != nil ? .green : .primary)
                
                // Previous (from history)
                Text(previousSetHint(for: exerciseName, setIndex: setNumber - 1))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70)
                
                // Weight input
                TextField("0", text: Binding<String>(
                    get: {
                        let id = set.wrappedValue.id
                        if let existing = weightTextBySet[id] {
                            return existing
                        }
                        let value = set.wrappedValue.weight
                        if value == 0 {
                            return ""
                        }
                        return String(value)
                    },
                    set: { newValue in
                        let id = set.wrappedValue.id
                        weightTextBySet[id] = newValue
                        if let numeric = Double(newValue) {
                            set.wrappedValue.weight = numeric
                        }
                    }
                ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .focused($isInputFocused)
                    .onChange(of: set.wrappedValue.weight) { _, newWeight in
                        onValueChange(nil, newWeight)
                    }
                
                // Reps input
                TextField("0", text: Binding<String>(
                    get: {
                        let id = set.wrappedValue.id
                        if let existing = repsTextBySet[id] {
                            return existing
                        }
                        let value = set.wrappedValue.reps
                        if value == 0 {
                            return ""
                        }
                        return String(value)
                    },
                    set: { newValue in
                        let id = set.wrappedValue.id
                        repsTextBySet[id] = newValue
                        if let numeric = Int(newValue) {
                            set.wrappedValue.reps = numeric
                        }
                    }
                ))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .focused($isInputFocused)
                    .onChange(of: set.wrappedValue.reps) { _, newReps in
                        onValueChange(newReps, nil)
                    }
                
                Spacer()
                
                // Complete button
                Button {
                    if set.wrappedValue.completedAt == nil {
                        set.wrappedValue.completedAt = Date()
                        // Start rest timer
                        let endTime = Date().addingTimeInterval(TimeInterval(defaultRestSeconds))
                        restEndTime = endTime
                        restTimeRemaining = defaultRestSeconds
                        isResting = true
                    } else {
                        set.wrappedValue.completedAt = nil
                    }
                    onToggleComplete()
                } label: {
                    Image(systemName: set.wrappedValue.completedAt != nil ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(set.wrappedValue.completedAt != nil ? .green : .gray)
                }
            }
            
            HStack(spacing: 8) {
                // Side selector
                Picker("Side", selection: set.side) {
                    Text("B").tag(WorkoutSetRecord.Side.both)
                    Text("L").tag(WorkoutSetRecord.Side.left)
                    Text("R").tag(WorkoutSetRecord.Side.right)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)

                // RPE input
                TextField("RPE", text: Binding<String>(
                    get: {
                        let id = set.wrappedValue.id
                        if let existing = rpeTextBySet[id] {
                            return existing
                        }
                        guard let value = set.wrappedValue.rpe else { return "" }
                        if value == 0 { return "" }
                        return String(format: "%.1f", value)
                    },
                    set: { newValue in
                        let id = set.wrappedValue.id
                        rpeTextBySet[id] = newValue
                        let cleaned = newValue.replacingOccurrences(of: ",", with: ".")
                        if let numeric = Double(cleaned), numeric > 0 {
                            set.wrappedValue.rpe = numeric
                        } else {
                            set.wrappedValue.rpe = nil
                        }
                        persistDraft()
                    }
                ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 64)
                    .focused($isInputFocused)

                // RIR input
                TextField("RIR", text: Binding<String>(
                    get: {
                        let id = set.wrappedValue.id
                        if let existing = rirTextBySet[id] {
                            return existing
                        }
                        guard let value = set.wrappedValue.rir else { return "" }
                        return String(value)
                    },
                    set: { newValue in
                        let id = set.wrappedValue.id
                        rirTextBySet[id] = newValue
                        if let numeric = Int(newValue), numeric >= 0 {
                            set.wrappedValue.rir = numeric
                        } else {
                            set.wrappedValue.rir = nil
                        }
                        persistDraft()
                    }
                ))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                    .focused($isInputFocused)
                
                // Note field
                TextField("Note (optional)", text: Binding(set.note, replacingNilWith: ""))
                    .font(.caption)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(set.wrappedValue.completedAt != nil ? Color.green.opacity(0.1) : Color.clear)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete Set", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Add Exercise Button
    private var addExerciseButton: some View {
        Button {
            showAddExercise = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Exercise")
            }
            .font(.headline)
            .foregroundColor(.gainAccent)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gainAccent, style: StrokeStyle(lineWidth: 2, dash: [8]))
            )
        }
    }
    
    // MARK: - Add Exercise Sheet
    private var addExerciseSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Exercise name", text: $newExerciseName)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                // Browse Library
                NavigationLink {
                    ExerciseLibraryView { definition in
                        addExercise(name: definition.name)
                    }
                    .environmentObject(exerciseLibrary)
                } label: {
                    HStack {
                        Image(systemName: "book.fill")
                        Text("Browse Library")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                // Quick suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Add")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row", "Pull-ups", "Bicep Curl", "Tricep Extension"], id: \.self) { name in
                            Button {
                                addExercise(name: name)
                            } label: {
                                Text(name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddExercise = false
                        newExerciseName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addExercise(name: newExerciseName)
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            // Rest Timer Quick Adjust
            Menu {
                ForEach([30, 60, 90, 120, 180], id: \.self) { seconds in
                    Button("\(seconds)s") {
                        defaultRestSeconds = seconds
                        if isResting {
                            let newEnd = Date().addingTimeInterval(TimeInterval(seconds))
                            restEndTime = newEnd
                            restTimeRemaining = seconds
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "timer")
                    Text("\(formatRestTime(restTimeRemaining))")
                    Text("\(defaultRestSeconds)s")
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gainCardSoft)
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Finish Button
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                showEndConfirmation = true
            } label: {
                Text("Finish Session")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: Color.green.opacity(0.3), radius: 4, y: 2)
            }
        }
        .padding()
        .background(Color.gainCard)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.15)),
            alignment: .top
        )
    }
    
    // MARK: - Helper Functions
    
    private var completedSetsCount: Int {
        current.exercises.flatMap { $0.sets }.filter { $0.completedAt != nil }.count
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatRestTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
    
    private func previousPerformance(for exerciseName: String) -> String? {
        // Find the most recent *finished* workout containing this exercise
        let finished = store.records.filter { !$0.isUnfinished }
        for record in finished {
            if let exercise = record.exercises.first(where: { $0.name.lowercased() == exerciseName.lowercased() }) {
                if let bestSet = exercise.sets.max(by: { ($0.weight * Double($0.reps)) < ($1.weight * Double($1.reps)) }) {
                    return "\(Int(bestSet.weight))kg × \(bestSet.reps)"
                }
            }
        }
        return nil
    }
    
    private func previousSetHint(for exerciseName: String, setIndex: Int) -> String {
        let finished = store.records.filter { !$0.isUnfinished }
        for record in finished {
            if let exercise = record.exercises.first(where: { $0.name.lowercased() == exerciseName.lowercased() }) {
                if setIndex < exercise.sets.count {
                    let set = exercise.sets[setIndex]
                    return "\(Int(set.weight))×\(set.reps)"
                }
            }
        }
        return "-"
    }
    
    private func isPersonalRecord(exercise: String, weight: Double, reps: Int) -> Bool {
        let volume = weight * Double(reps)
        guard volume > 0 else { return false }
        
        let finished = store.records.filter { !$0.isUnfinished }
        for record in finished {
            if let ex = record.exercises.first(where: { $0.name.lowercased() == exercise.lowercased() }) {
                for set in ex.sets {
                    if set.weight * Double(set.reps) >= volume {
                        return false
                    }
                }
            }
        }
        return true
    }

    // All-time best set (by volume) for a given exercise, across finished sessions
    private func bestSet(for exerciseName: String) -> (weight: Double, reps: Int)? {
        let finished = store.records.filter { !$0.isUnfinished }
        var bestVolume: Double = 0
        var bestWeight: Double = 0
        var bestReps: Int = 0

        for record in finished {
            if let exercise = record.exercises.first(where: { $0.name.lowercased() == exerciseName.lowercased() }) {
                for set in exercise.sets {
                    let volume = set.weight * Double(set.reps)
                    if volume > bestVolume {
                        bestVolume = volume
                        bestWeight = set.weight
                        bestReps = set.reps
                    }
                }
            }
        }

        return bestVolume > 0 ? (bestWeight, bestReps) : nil
    }

    // Simple summary string for progressive overload recommendation
    private func nextPlanSummary(for exerciseName: String) -> String? {
        let finished = store.records.filter { !$0.isUnfinished }
        let increment = overloadSettings.increment(for: exerciseName)
        let repRange = overloadSettings.targetRepsPerSet(for: exerciseName)
        let minInc = overloadSettings.minIncrementKg(for: exerciseName)
        let maxInc = overloadSettings.maxIncrementKg(for: exerciseName)
        let deloadEvery = overloadSettings.deloadEveryWeeks(for: exerciseName)
        let lookback = deloadEvery != nil ? max(3, min(6, deloadEvery ?? 4)) : 4
        let params = ProgressionParameters(
            targetRepsPerSet: repRange ?? (6...12),
            weightIncrement: increment,
            minIncrementKg: minInc,
            maxIncrementKg: maxInc,
            stallLookbackSessions: lookback
        )
        guard let plan = ProgressiveOverloadEngine.planNextSession(
            for: exerciseName,
            from: finished,
            params: params
        ) else {
            return nil
        }

        guard let first = plan.plannedSets.first else { return nil }
        let sets = plan.plannedSets.count
        return "\(sets) × \(first.reps) @ \(Int(first.weight))kg"
    }

    private func openBodyWeightLogger() {
        bodyWeightDate = Date()
        if bodyWeightText.isEmpty, let latest = weightStore.entries.first {
            bodyWeightText = String(format: "%.1f", latest.weight)
        }
        showLogBodyWeight = true
    }

    private func persistDraft() {
        current.start = startTime
        current.isUnfinished = true
        if let _ = store.records.firstIndex(where: { $0.id == current.id }) {
            store.update(current)
        } else {
            store.add(current)
        }
    }

    private func addExercise(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let newExercise = WorkoutExerciseRecord(
            name: trimmed,
            sets: [WorkoutSetRecord(reps: 0, weight: 0)]
        )
        current.exercises.append(newExercise)
        expandedExercises.insert(newExercise.id)
        
        showAddExercise = false
        newExerciseName = ""
        persistDraft()
    }
    
    private func saveAndEnd() {
        let endTime = Date()
        current.end = endTime
        current.duration = endTime.timeIntervalSince(current.start)
        
        // Only save if there's meaningful data
        let hasData = current.exercises.contains { exercise in
            exercise.sets.contains { $0.completedAt != nil }
        }

        guard hasData else {
            // If there was a draft saved, remove it on discard of empty session
            if let _ = store.records.firstIndex(where: { $0.id == current.id && $0.isUnfinished }) {
                store.delete(id: current.id)
            }
            dismiss()
            return
        }

        current.isUnfinished = false

        if let _ = store.records.firstIndex(where: { $0.id == current.id }) {
            store.update(current)
        } else {
            store.add(current)
        }

        dismiss()
    }

    private var logBodyWeightSheet: some View {
        NavigationView {
            Form {
                Section("Body Weight") {
                    HStack {
                        TextField("Weight", text: $bodyWeightText)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                    DatePicker("Date", selection: $bodyWeightDate, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Log Body Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showLogBodyWeight = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cleaned = bodyWeightText.replacingOccurrences(of: ",", with: ".")
                        if let value = Double(cleaned), value > 0 {
                            weightStore.add(WeightEntry(date: bodyWeightDate, weight: value))
                        }
                        showLogBodyWeight = false
                    }
                    .disabled(Double(bodyWeightText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }
}

// Helper to bind optional String to TextField
fileprivate extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith fallback: String) {
        self.init(get: { source.wrappedValue ?? fallback },
                  set: { newValue in source.wrappedValue = newValue.isEmpty ? nil : newValue })
    }
}

// MARK: - Plate Calculator
struct PlateCalculatorView: View {
    @Binding var targetWeight: Double
    @Environment(\.dismiss) private var dismiss
    @State private var barWeight: Double = 20 // Standard barbell
    
    private let availablePlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
    
    private var platesNeeded: [(weight: Double, count: Int)] {
        var remaining = (targetWeight - barWeight) / 2 // Per side
        var result: [(weight: Double, count: Int)] = []
        
        for plate in availablePlates {
            let count = Int(remaining / plate)
            if count > 0 {
                result.append((weight: plate, count: count))
                remaining -= Double(count) * plate
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Target Weight") {
                    HStack {
                        TextField("Weight", value: $targetWeight, format: .number)
                            .keyboardType(.decimalPad)
                        Text("kg")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Bar Weight") {
                    Picker("Bar", selection: $barWeight) {
                        Text("20 kg (Standard)").tag(20.0)
                        Text("15 kg (Women's)").tag(15.0)
                        Text("10 kg (Training)").tag(10.0)
                    }
                }
                
                Section("Plates Per Side") {
                    if platesNeeded.isEmpty {
                        Text("No plates needed")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(platesNeeded, id: \.weight) { plate in
                            HStack {
                                Text("\(plate.count)x")
                                    .font(.headline)
                                Text("\(plate.weight, specifier: "%.2f") kg")
                                Spacer()
                                ForEach(0..<plate.count, id: \.self) { _ in
                                    Circle()
                                        .fill(colorForPlate(plate.weight))
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func colorForPlate(_ weight: Double) -> Color {
        switch weight {
        case 25: return .red
        case 20: return .blue
        case 15: return .yellow
        case 10: return .green
        case 5: return .white
        default: return .gray
        }
    }
}

// MARK: - Preview
struct WorkoutSessionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WorkoutSessionView(template: WorkoutTemplate(name: "Push Day", exercises: ["Bench Press", "Overhead Press", "Incline DB Press"]))
                .environmentObject(WeightStore.shared)
        }
    }
}
