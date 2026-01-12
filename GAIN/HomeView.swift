import SwiftUI
import FirebaseAuth

struct HomeView: View {
    @EnvironmentObject var dailyStatsStore: DailyStatsStore
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var templateStore: TemplateStore
    @EnvironmentObject var waterIntakeStore: WaterIntakeStore
    @EnvironmentObject var stepsSleepHealthStore: StepsSleepHealthStore

    @State private var showLogSheet = false
    @State private var logType: LogType?
    @State private var showStartSheet = false
    @State private var selectedTemplate: WorkoutTemplate?
    @State private var showWorkoutSession = false
    @State private var showWaterLogger = false
    @State private var appear = false

    enum LogType: String, CaseIterable {
        case water = "Water"
        case calories = "Calories"
        case steps = "Steps"
        case sleep = "Sleep"

        var icon: String {
            switch self {
            case .water: return "drop.fill"
            case .calories: return "flame.fill"
            case .steps: return "figure.walk"
            case .sleep: return "moon.zzz.fill"
            }
        }

        var unit: String {
            switch self {
            case .water: return "ml"
            case .calories: return "kcal"
            case .steps: return "steps"
            case .sleep: return "hours"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with greeting and streak
                    headerSection
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : -20)
                    
                    // Workout Streak Card
                    workoutStreakCard
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appear)
                    
                    // Last Workout Summary (if exists)
                    if let lastWorkout = workoutStore.records.first {
                        lastWorkoutCard(workout: lastWorkout)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: appear)
                    }
                    
                    // Quick Stats with tap interactions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Today's Stats")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.gainTextPrimary)
                            .padding(.horizontal)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 10)
                            .animation(.easeOut(duration: 0.5).delay(0.3), value: appear)
                        
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(Array([
                                ("Calories", "\(dailyStatsStore.todayStats.calories)", dailyStatsStore.calorieProgress, Color.orange, "flame", { logType = .calories; showLogSheet = true }),
                                ("Water", "\(dailyStatsStore.todayStats.water)", dailyStatsStore.waterProgress, Color.blue, "drop", { showWaterLogger = true }),
                                ("Steps", "\(dailyStatsStore.todayStats.steps)", dailyStatsStore.stepsProgress, Color.green, "figure.walk.motion", { stepsSleepHealthStore.syncToday() }),
                                ("Sleep", String(format: "%.1f h", dailyStatsStore.todayStats.sleep), dailyStatsStore.sleepProgress, Color.purple, "moon", { stepsSleepHealthStore.syncToday() })
                            ].enumerated()), id: \.offset) { index, stat in
                                TappableStatBox(
                                    title: stat.0,
                                    value: stat.1,
                                    goal: "",
                                    progress: stat.2,
                                    color: stat.3,
                                    icon: stat.4,
                                    onTap: stat.5
                                )
                                .opacity(appear ? 1 : 0)
                                .scaleEffect(appear ? 1 : 0.8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4 + Double(index) * 0.1), value: appear)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Start Workout Button (Primary CTA)
                    Button {
                        let impactMed = UIImpactFeedbackGenerator(style: .medium)
                        impactMed.impactOccurred()
                        showStartSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                            Text("Start Workout")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                Color.gainVibrantGradient
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.2), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        )
                        .cornerRadius(20)
                        .shadow(color: Color(red: 0xFF/255.0, green: 0x00/255.0, blue: 0x7B/255.0).opacity(0.4), radius: 20, x: 0, y: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                    }
                    .padding(.horizontal)
                    .opacity(appear ? 1 : 0)
                    .scaleEffect(appear ? 1 : 0.9)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: appear)

                    // Personal Records
                    personalRecordsSection

                    // Analytics section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("This Week")
                                .font(.title3).bold()
                                .foregroundColor(.gainTextPrimary)
                            Spacer()
                            NavigationLink("View All", destination: HistoryView())
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(), GridItem()], spacing: 12) {
                            InsightCard(
                                label: "Workouts",
                                value: "\(workoutsThisWeek)",
                                color: .teal,
                                icon: "figure.strengthtraining.traditional"
                            )
                            InsightCard(
                                label: "Total Volume",
                                value: totalVolumeFormatted,
                                color: .teal,
                                icon: "scalemass.fill"
                            )
                            InsightCard(
                                label: "Avg Duration",
                                value: averageDurationFormatted,
                                color: .teal,
                                icon: "timer"
                            )
                            InsightCard(
                                label: "Consistency",
                                value: "\(consistencyPercentage)%",
                                color: .teal,
                                icon: "calendar.badge.checkmark"
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    // HealthKit sync footer
                    healthKitSyncSection
                    Spacer(minLength: 40)
                }
                .padding(.top)
            }
            .background(Color.gainBackgroundGradient.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                stepsSleepHealthStore.syncToday()
            }
            .onAppear {
                withAnimation {
                    appear = true
                }
            }
            .navigationDestination(isPresented: $showWaterLogger) {
                WaterLoggerView()
                    .environmentObject(dailyStatsStore)
                    .environmentObject(waterIntakeStore)
            }
        }
        .sheet(isPresented: $showLogSheet) {
            if let type = logType {
                LogDataSheet(type: type)
                    .environmentObject(dailyStatsStore)
            }
        }
        .sheet(isPresented: $showStartSheet) {
            WorkoutStartSheet(
                templates: templateStore.templates.map { model in
                    WorkoutTemplate(
                        name: model.name,
                        exercises: model.exercises.map { $0.name }
                    )
                }
            ) { template in
                selectedTemplate = template
                showStartSheet = false
                showWorkoutSession = true
            }
        }
        .fullScreenCover(isPresented: $showWorkoutSession) {
            NavigationView {
                if let template = selectedTemplate {
                    WorkoutSessionView(template: template)
                        .environmentObject(ExerciseLibraryStore())
                } else {
                    WorkoutSessionView()
                        .environmentObject(ExerciseLibraryStore())
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GAIN")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gainAccent, Color.gainAccentSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.gainAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                Spacer()
                
                Menu {
                    Section("Account") {
                        Text(AuthManager.shared.currentUser?.email ?? "Not signed in")
                        Button(role: .destructive, action: {
                            AuthManager.shared.signOut()
                        }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    
                    Section("Backup") {
                        Button(action: {
                            SyncManager.shared.performFullSync()
                        }) {
                            Label("Sync Now", systemImage: "arrow.clockwise.icloud")
                        }
                    }
                } label: {
                    if let photoURL = AuthManager.shared.currentUser?.photoURL {
                        AsyncImage(url: photoURL) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gainAccent.opacity(0.5), lineWidth: 2))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(Color.gainAccent)
                    }
                }
            }

            Text(greetingText)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.gainTextPrimary)

            Text(Date(), style: .date)
                .foregroundColor(.gainTextSecondary)
                .font(.system(size: 15, weight: .medium, design: .rounded))
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<12: return "Good Morning 🌞"
        case 12..<17: return "Good Afternoon ☀️"
        default: return "Good Evening 🌙"
        }
    }
    
    // MARK: - Workout Streak Card
    private var workoutStreakCard: some View {
        HStack(spacing: 20) {
            // Streak count
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("\(workoutStreak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.gainAccent, Color.gainAccentSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Text("Day Streak")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gainTextSecondary)
            }
            
            Spacer()
            
            // Weekly goal progress
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(workoutsThisWeek)/\(weeklyWorkoutGoal)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.gainTextPrimary)
                Text("Weekly Goal")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.gainTextSecondary)
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.gainCard.opacity(0.6))
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.gainAccent.opacity(0.1), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [Color.gainAccent.opacity(0.4), Color.gainAccent.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal)
    }
    
    // MARK: - Last Workout Card
    private func lastWorkoutCard(workout: WorkoutRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Workout")
                    .font(.headline)
                    .foregroundColor(.gainTextSecondary)
                Spacer()
                Text(workout.start, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(workout.templateName ?? "Custom Workout")
                    .font(.title3).bold()
                    .foregroundColor(.gainTextPrimary)
                
                HStack(spacing: 20) {
                    Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                        .font(.subheadline)
                    Label(formatDuration(workout.duration), systemImage: "timer")
                        .font(.subheadline)
                    Label(String(format: "%.0f kg", workout.totalVolume), systemImage: "scalemass")
                        .font(.subheadline)
                }
                .foregroundColor(.gainTextSecondary)
            }
        }
        .padding()
        .background(Color.gainCard)
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Personal Records Section
    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.gainAccent)
                Text("Personal Records")
                    .font(.title3).bold()
                    .foregroundColor(.gainTextPrimary)
            }
            .padding(.horizontal)
            
            if personalRecords.isEmpty {
                Text("Complete workouts to set PRs")
                    .foregroundColor(.gainTextSecondary)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(personalRecords.prefix(5), id: \.exerciseName) { pr in
                            PRCard(exerciseName: pr.exerciseName, weight: pr.maxWeight, reps: pr.reps)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - HealthKit Sync Section
    private var healthKitSyncSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    stepsSleepHealthStore.syncToday()
                    let impactLight = UIImpactFeedbackGenerator(style: .light)
                    impactLight.impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync from Apple Health")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gainCard)
                    .cornerRadius(8)
                }
                
                if let error = stepsSleepHealthStore.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                } else if !stepsSleepHealthStore.isAuthorized {
                    Label("Health permissions needed", systemImage: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else {
                    Label("Health sync active", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Analytics Helpers
    private var workoutsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workoutStore.records.filter { $0.start >= weekAgo }.count
    }
    
    private var weeklyWorkoutGoal: Int { 6 } // Configurable
    
    private var workoutStreak: Int {
        var streak = 0
        var currentDate = Calendar.current.startOfDay(for: Date())
        
        while true {
            let hasWorkout = workoutStore.records.contains { workout in
                Calendar.current.isDate(workout.start, inSameDayAs: currentDate)
            }
            
            if hasWorkout {
                streak += 1
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else if streak == 0 {
                // No workout today, check yesterday to see if we had a streak going
                currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                let hasWorkoutYesterday = workoutStore.records.contains { workout in
                    Calendar.current.isDate(workout.start, inSameDayAs: currentDate)
                }
                if hasWorkoutYesterday {
                    streak += 1
                    currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return streak
    }
    
    private var totalVolumeFormatted: String {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let total = workoutStore.records.filter { $0.start >= weekAgo }.reduce(0.0) { $0 + $1.totalVolume }
        return total >= 1000 ? String(format: "%.1fk", total / 1000) : String(format: "%.0f", total)
    }
    
    private var averageDurationFormatted: String {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let workouts = workoutStore.records.filter { $0.start >= weekAgo }
        guard !workouts.isEmpty else { return "0m" }
        let avg = workouts.reduce(0.0) { $0 + $1.duration } / Double(workouts.count)
        return "\(Int(avg / 60))m"
    }
    
    private var consistencyPercentage: Int {
        return min((workoutsThisWeek * 100) / weeklyWorkoutGoal, 100)
    }
    
    private var personalRecords: [(exerciseName: String, maxWeight: Double, reps: Int)] {
        var records: [String: (weight: Double, reps: Int)] = [:]
        
        for workout in workoutStore.records {
            for exercise in workout.exercises {
                for set in exercise.sets where set.isCompleted {
                    let volume = set.weight * Double(set.reps)
                    if let existing = records[exercise.name] {
                        let existingVolume = existing.weight * Double(existing.reps)
                        if volume > existingVolume {
                            records[exercise.name] = (set.weight, set.reps)
                        }
                    } else {
                        records[exercise.name] = (set.weight, set.reps)
                    }
                }
            }
        }
        
        return records.map { (exerciseName: $0.key, maxWeight: $0.value.weight, reps: $0.value.reps) }
            .sorted { $0.maxWeight * Double($0.reps) > $1.maxWeight * Double($1.reps) }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - New Components

struct TappableStatBox: View {
    let title: String
    let value: String
    let goal: String
    let progress: Double
    let color: Color
    let icon: String
    let onTap: () -> Void
    
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.2))
                        )
                }
                
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.gainTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gainTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(20)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.15), Color.clear]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct PRCard: View {
    let exerciseName: String
    let weight: Double
    let reps: Int
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Spacer()
            }
            
            Text(exerciseName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(2)
                .frame(height: 38, alignment: .top)
                .foregroundColor(.gainTextPrimary)
            
            HStack(spacing: 6) {
                Text(String(format: "%.1f", weight))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.gainTextPrimary)
                Text("kg")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gainTextSecondary)
                Text("×")
                    .foregroundColor(.gainTextSecondary)
                    .font(.system(size: 13))
                Text("\(reps)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.gainTextPrimary)
            }
        }
        .frame(width: 150)
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.4), Color.orange.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

struct ProgressCard: View {
    let title: String
    let progress: Double
    let current: String
    let goal: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title).bold().foregroundColor(color)
                Spacer()
                Text("\(current) / \(goal)")
                    .font(.caption).foregroundColor(.secondary)
            }
            ProgressView(value: progress)
                .tint(color)
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct InsightCard: View {
    let label: String
    let value: String
    let color: Color
    let icon: String
    
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 32)
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.gainTextPrimary)
            
            Text(label)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.gainTextSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}
