import SwiftUI

// MARK: - Start Workout Sheet (Clean implementation using RoutineScheduleManager)
struct StartWorkoutSheet: View {
    @EnvironmentObject var templateStore: TemplateStore
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject private var scheduleManager = RoutineScheduleManager.shared

    /// Callback to start a session with an optional prebuilt workout record
    let onStart: (WorkoutRecord?) -> Void
    
    // Computed property to get today's template - always fresh data
    private var todaysTemplate: TemplateModel? {
        scheduleManager.todaysTemplate(from: templateStore.templates)
    }

    var body: some View {
        NavigationView {
            List {
                // Today's Routine Section
                Section(header: Text("Today's Routine")) {
                    todaysRoutineRow
                }
                
                // Quick Start Section
                Section(header: Text("Quick Start")) {
                    Button {
                        startTodaysRoutine()
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.green)
                            Text("Start Today's Routine")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(todaysTemplate == nil)
                    
                    NavigationLink {
                        TemplatePickerView(onSelect: { template in
                            startWithTemplate(template)
                        })
                        .environmentObject(templateStore)
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                                .foregroundColor(.blue)
                            Text("Choose a Routine")
                        }
                    }
                    
                    Button {
                        startEmptyWorkout()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.purple)
                            Text("Start Empty Workout")
                        }
                    }
                }
            }
            .navigationTitle("Start Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Today's Routine Row
    
    private var todaysRoutineRow: some View {
        let todayName = Weekday.today.fullName
        let template = todaysTemplate
        let isRestDay = template == nil
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(todayName)
                    .font(.headline)
                Spacer()
                if isRestDay {
                    Text("Rest Day")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Text(template?.name ?? "")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            
            if let template = template {
                Text("\(template.exercises.count) exercises")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Actions
    
    private func startTodaysRoutine() {
        // Use the computed property to get fresh template data
        guard let template = todaysTemplate else {
            // Rest day or no template - start empty
            onStart(nil)
            presentationMode.wrappedValue.dismiss()
            return
        }
        
        let record = RoutineScheduleManager.createWorkoutRecord(from: template)
        
        // IMPORTANT: Call onStart BEFORE dismiss to avoid race condition
        onStart(record)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func startWithTemplate(_ template: TemplateModel) {
        let record = RoutineScheduleManager.createWorkoutRecord(from: template)
        onStart(record)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func startEmptyWorkout() {
        // Explicitly create an empty record so we always pass a valid object
        let record = WorkoutRecord()
        onStart(record)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Template Picker View
struct TemplatePickerView: View {
    @EnvironmentObject var templateStore: TemplateStore
    @Environment(\.presentationMode) var presentationMode
    
    var onSelect: (TemplateModel) -> Void

    var body: some View {
        List {
            if templateStore.templates.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No templates yet")
                            .font(.headline)
                        Text("Create templates in the Templates tab")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section(header: Text("Your Routines")) {
                    ForEach(templateStore.templates) { template in
                        Button {
                            onSelect(template)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("\(template.exercises.count) exercises")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Choose Routine")
    }
}

// MARK: - Today Summary View
struct TodaySummaryView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var dailyStatsStore: DailyStatsStore
    @EnvironmentObject var stepsSleepHealthStore: StepsSleepHealthStore

    private var todaysWorkouts: [WorkoutRecord] {
        let cal = Calendar.current
        return workoutStore.records.filter { cal.isDateInToday($0.start) && !$0.isUnfinished }
    }

    private var todaysVolume: Double {
        todaysWorkouts.reduce(0.0) { $0 + $1.totalVolume }
    }

    private var todaysDuration: TimeInterval {
        todaysWorkouts.reduce(0.0) { $0 + $1.duration }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Today's Summary")
                    .font(.title2).bold()

                // Training summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training")
                        .font(.headline)
                    if todaysWorkouts.isEmpty {
                        Text("No workouts logged today yet.")
                            .foregroundColor(.secondary)
                    } else {
                        Text("Workouts: \(todaysWorkouts.count)")
                        Text(String(format: "Volume: %.0f kg", todaysVolume))
                        let minutes = Int(todaysDuration) / 60
                        Text("Duration: \(minutes)m")
                    }
                }
                .padding()
                .background(Color.gainCard)
                .cornerRadius(12)

                // Daily stats summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily Stats")
                        .font(.headline)

                    let stats = dailyStatsStore.todayStats
                    let goals = dailyStatsStore.goals

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Calories: \(stats.calories) / \(goals.dailyCalories)")
                        Text("Water: \(stats.water) ml / \(goals.dailyWater) ml")
                        Text("Steps: \(stats.steps) / \(goals.dailySteps)")
                        Text(String(format: "Sleep: %.1f h / %.1f h", stats.sleep, goals.dailySleep))
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color.gainCard)
                .cornerRadius(12)

                Spacer(minLength: 20)
            }
            .padding()
        }
        .navigationTitle("Today")
        .onAppear {
            stepsSleepHealthStore.syncToday()
        }
    }
}
