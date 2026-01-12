import SwiftUI

struct WorkoutMenuView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var templateStore: TemplateStore
    @ObservedObject private var scheduleManager = RoutineScheduleManager.shared

    @State private var showingStart = false
    @State private var showingMissed = false
    @State private var showingContinueConfirm = false
    // Removed showWorkoutSession as we rely on selectedRecord presence
    @State private var selectedRecord: WorkoutRecord? = nil
    
    // Fix for modal presentation race condition
    @State private var pendingRecordToStart: WorkoutRecord? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Today's Routine Card
                    todaysRoutineCard
                    
                    // Main Action Buttons
                    actionButtonsSection
                    
                    // Quick Stats
                    quickStatsSection
                    
                    // Recent Workouts Preview
                    recentWorkoutsSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }

            .background(Color.gainBackgroundGradient.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)

            .alert(isPresented: $showingContinueConfirm) {
                Alert(
                    title: Text("Resume unfinished session?"),
                    message: Text("Resume or delete the unfinished session."),
                    primaryButton: .default(Text("Resume")) {
                        if let unfinished = workoutStore.records.first(where: { $0.isUnfinished }) {
                            selectedRecord = unfinished
                        }
                    },
                    secondaryButton: .destructive(Text("Delete")) {
                        if let unfinished = workoutStore.records.first(where: { $0.isUnfinished }) {
                            workoutStore.delete(id: unfinished.id)
                        }
                    }
                )
            }
            .sheet(isPresented: $showingStart) {
                StartWorkoutSheet { record in
                    // Instead of launching immediately, set pending and dismiss
                    pendingRecordToStart = record
                    showingStart = false
                }
                .environmentObject(templateStore)
            }
            .sheet(isPresented: $showingMissed) {
                MissedWorkoutSheet { record in
                    // Start immediately for missed workouts
                    selectedRecord = record
                }
                .environmentObject(templateStore)
            }
            // Listen for StartWorkoutSheet dismissal to launch session
            // iOS 17+ syntax usually requires 2 parameters for old behavior, or 0.
            // Using 2 params (oldValue, newValue) works for modernization.
            .onChange(of: showingStart) { _, isPresented in
                if !isPresented {
                    if let pending = pendingRecordToStart {
                        // Small delay to allow sheet animation to clear
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            selectedRecord = pending
                            pendingRecordToStart = nil
                        }
                    }
                }
            }
            // Use item-based presentation to guarantee record availability
            .fullScreenCover(item: $selectedRecord) { record in
                NavigationView {
                    WorkoutSessionView(record: record)
                        .environmentObject(ExerciseLibraryStore())
                        .id(record.id) // Ensure fresh view state
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Workout")
                .font(.largeTitle).bold()
                .foregroundColor(.gainTextPrimary)
            Text(greetingMessage)
                .font(.subheadline)
                .foregroundColor(.gainTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: - Today's Routine Card
    private var todaysRoutineCard: some View {
        let todayName = Weekday.today.fullName
        let template = scheduleManager.todaysTemplate(from: templateStore.templates)
        let isRestDay = scheduleManager.isTodayRestDay
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Routine")
                        .font(.caption)
                        .foregroundColor(.gainTextSecondary)
                        .textCase(.uppercase)
                    
                    Text(template?.name ?? "Rest Day")
                        .font(.title2).bold()
                        .foregroundColor(isRestDay ? .secondary : .gainAccent)
                }
                
                Spacer()
                
                Image(systemName: isRestDay ? "moon.fill" : "calendar")
                    .font(.title)
                    .foregroundColor(isRestDay ? .secondary : .gainAccentSoft)
            }
            
            if let template = template {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(template.exercises.count) exercises planned")
                        .font(.caption)
                        .foregroundColor(.gainTextSecondary)
                    
                    // Exercise preview
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(template.exercises.prefix(5)) { exercise in
                                Text(exercise.name)
                                    .font(.caption2)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.gainAccent.opacity(0.15))
                                    .foregroundColor(.gainAccent)
                                    .cornerRadius(8)
                            }
                            if template.exercises.count > 5 {
                                Text("+\(template.exercises.count - 5)")
                                    .font(.caption2)
                                    .foregroundColor(.gainTextSecondary)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("It's \(todayName) — take a break or start an unscheduled workout!")
                        .font(.caption)
                        .foregroundColor(.gainTextSecondary)
                    NavigationLink("Set up weekly schedule", destination: TemplatesView())
                        .font(.footnote).bold()
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isRestDay ? Color.gray.opacity(0.04) : Color.purple.opacity(0.04))
                .overlay(
                    LinearGradient(
                        colors: [isRestDay ? Color.gray.opacity(0.2) : Color.gainAccent.opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isRestDay ? Color.gray.opacity(0.25) : Color.gainAccent.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 8)
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Start Workout Button
            Button {
                showingStart = true
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Start Workout")
                            .font(.title3).bold()
                            .foregroundColor(.white)
                        Text("Launch a new training session")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(18)
                .background(Color.gainVibrantGradient)
                .cornerRadius(18)
                .shadow(color: Color.gainPink.opacity(0.35), radius: 12, y: 8)
            }
            
            HStack(spacing: 12) {
                // Continue Session
                if workoutStore.records.contains(where: { $0.isUnfinished }) {
                    Button {
                        showingContinueConfirm = true
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                                .foregroundColor(.gainAccent)
                            Text("Continue")
                                .font(.subheadline).bold()
                                .foregroundColor(.gainTextPrimary)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gainVibrantGradient)
                        .cornerRadius(15)
                        .shadow(color: Color.gainPink.opacity(0.35), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.gainAccent.opacity(0.25), lineWidth: 1)
                        )
                    }
                }
                
                // Add Missed Workout
                Button {
                    showingMissed = true
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundColor(.gainAccent)
                        Text("Add Missed")
                            .font(.subheadline).bold()
                            .foregroundColor(.gainTextPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.gainAccent.opacity(0.25), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline)
                .foregroundColor(.gainTextPrimary)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                MiniStatCard(
                    value: "\(workoutsThisWeek)",
                    label: "Workouts",
                    icon: "dumbbell.fill",
                    color: .gainAccent
                )
                MiniStatCard(
                    value: totalVolumeThisWeek,
                    label: "Volume",
                    icon: "scalemass.fill",
                    color: .gainAccentSoft
                )
                MiniStatCard(
                    value: avgDurationThisWeek,
                    label: "Avg Time",
                    icon: "timer",
                    color: .gainAccent
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Recent Workouts Section
    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundColor(.gainTextPrimary)
                Spacer()
                NavigationLink("View All", destination: WorkoutHistoryView())
                    .font(.subheadline)
                    .foregroundColor(.gainAccentSoft)
            }
            .padding(.horizontal)
            
            if workoutStore.records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 40))
                        .foregroundColor(.gainAccentSoft.opacity(0.5))
                    Text("No workouts yet")
                        .font(.subheadline)
                        .foregroundColor(.gainTextSecondary)
                    Text("Start your first workout to see it here")
                        .font(.caption)
                        .foregroundColor(.gainTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(workoutStore.records.prefix(3)) { record in
                        NavigationLink(destination: WorkoutHistoryDetailView(record: record)) {
                            MiniWorkoutCard(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Ready for a morning session?"
        } else if hour < 17 {
            return "Let's crush this afternoon workout!"
        } else {
            return "Time to finish strong tonight!"
        }
    }
    
    private var workoutsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workoutStore.records.filter { $0.start >= weekAgo }.count
    }
    
    private var totalVolumeThisWeek: String {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let total = workoutStore.records.filter { $0.start >= weekAgo }.reduce(0.0) { $0 + $1.totalVolume }
        return total >= 1000 ? String(format: "%.0fk", total / 1000) : String(format: "%.0f", total)
    }
    
    private var avgDurationThisWeek: String {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeek = workoutStore.records.filter { $0.start >= weekAgo }
        guard !thisWeek.isEmpty else { return "0m" }
        let avg = thisWeek.reduce(0.0) { $0 + $1.duration } / Double(thisWeek.count)
        return "\(Int(avg / 60))m"
    }
}

// MARK: - Supporting Components

struct MiniStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3).bold()
                .foregroundColor(.gainTextPrimary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gainTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    LinearGradient(
                        colors: [color.opacity(0.25), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
    }
}

struct MiniWorkoutCard: View {
    let record: WorkoutRecord
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(record.start, format: .dateTime.day())
                    .font(.headline)
                    .foregroundColor(.gainAccent)
                Text(record.start, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundColor(.gainTextSecondary)
            }
            .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.templateName ?? "Custom")
                    .font(.subheadline).bold()
                    .foregroundColor(.gainTextPrimary)
                
                HStack(spacing: 10) {
                    Label("\(record.exercises.count)", systemImage: "list.bullet")
                    Label(formatDuration(record.duration), systemImage: "timer")
                }
                .font(.caption2)
                .foregroundColor(.gainTextSecondary)
            }
            
            Spacer()
            
            Text(String(format: "%.0f kg", record.totalVolume))
                .font(.caption).bold()
                .foregroundColor(.gainAccent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes)m"
    }
}

struct MissedWorkoutSheet: View {
    @EnvironmentObject var templateStore: TemplateStore
    @Environment(\.presentationMode) var presentationMode

    var onCreate: (WorkoutRecord) -> Void

    @State private var selectedDate: Date = Date()
    @State private var selectedTemplateId: UUID?

    private var selectedTemplate: TemplateModel? {
        guard let id = selectedTemplateId else { return nil }
        return templateStore.templates.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Workout Date")) {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                }

                Section(header: Text("Routine")) {
                    if templateStore.templates.isEmpty {
                        Text("No templates yet. Create one in Templates.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Template", selection: $selectedTemplateId) {
                            Text("Select...").tag(nil as UUID?)
                            ForEach(templateStore.templates) { template in
                                Text(template.name).tag(Optional(template.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Missed Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        createRecord()
                    }
                    .disabled(selectedTemplate == nil)
                }
            }
        }
    }

    private func createRecord() {
        guard let template = selectedTemplate else { return }

        let record = RoutineScheduleManager.createWorkoutRecord(from: template)
        var mutableRecord = record
        mutableRecord = WorkoutRecord(
            id: record.id,
            templateName: record.templateName,
            start: selectedDate,
            end: record.end,
            duration: record.duration,
            exercises: record.exercises,
            notes: record.notes,
            isUnfinished: record.isUnfinished
        )

        onCreate(mutableRecord)
        presentationMode.wrappedValue.dismiss()
    }
}
