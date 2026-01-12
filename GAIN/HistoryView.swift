import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var sessionStore: SessionStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with stats
                    headerSection
                    
                    // Quick Stats Cards
                    quickStatsGrid
                    
                    // Recent Workouts
                    recentWorkoutsSection
                    
                    // Analytics & More
                    analyticsSection
                    
                    Spacer(minLength: 20)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("History")
                .font(.largeTitle).bold()
            Text("\(workoutStore.records.count) total workouts")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Stats Grid
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "This Week",
                value: "\(workoutsThisWeek)",
                subtitle: "workouts",
                icon: "figure.strengthtraining.traditional",
                color: .teal
            )
            StatCard(
                title: "Total Volume",
                value: totalVolumeFormatted,
                subtitle: "kg lifted",
                icon: "scalemass.fill",
                color: .orange
            )
            StatCard(
                title: "Avg Duration",
                value: avgDurationFormatted,
                subtitle: "per workout",
                icon: "timer",
                color: .blue
            )
            StatCard(
                title: "Streak",
                value: "\(workoutStreak)",
                subtitle: "days",
                icon: "flame.fill",
                color: .red
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Recent Workouts Section
    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.title3).bold()
                Spacer()
                NavigationLink("See All", destination: WorkoutHistoryView())
                    .font(.subheadline)
            }
            .padding(.horizontal)
            
            if workoutStore.records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.4))
                    Text("No workouts yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Your workout history will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(workoutStore.records.prefix(5)) { record in
                        NavigationLink(destination: WorkoutHistoryDetailView(record: record)) {
                            CompactWorkoutCard(record: record)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Analytics Section
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analytics & Insights")
                .font(.title3).bold()
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                AnalyticsNavButton(
                    title: "Exercise Progress",
                    subtitle: "Track your progress over time",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .teal,
                    destination: AnyView(WorkoutProgressView())
                )
                AnalyticsNavButton(
                    title: "Progressive Overload",
                    subtitle: "Weight & sets over time",
                    icon: "bolt.circle",
                    color: .orange,
                    destination: AnyView(ProgressiveOverloadHistoryView())
                )
                AnalyticsNavButton(
                    title: "Body Weight",
                    subtitle: "Log weight & track trends",
                    icon: "scalemass",
                    color: .pink,
                    destination: AnyView(WeightHistoryView())
                )
                AnalyticsNavButton(
                    title: "Daily Stats History",
                    subtitle: "View your daily nutrition & activity",
                    icon: "calendar",
                    color: .blue,
                    destination: AnyView(DailyStatsHistoryView())
                )
                AnalyticsNavButton(
                    title: "AI Insights",
                    subtitle: "Get personalized recommendations",
                    icon: "brain.head.profile",
                    color: .purple,
                    destination: AnyView(AIInsightsView())
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Computed Properties
    private var workoutsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workoutStore.records.filter { $0.start >= weekAgo }.count
    }
    
    private var totalVolumeFormatted: String {
        let total = workoutStore.records.reduce(0.0) { $0 + $1.totalVolume }
        return total >= 1000 ? String(format: "%.0fk", total / 1000) : String(format: "%.0f", total)
    }
    
    private var avgDurationFormatted: String {
        guard !workoutStore.records.isEmpty else { return "0m" }
        let avg = workoutStore.records.reduce(0.0) { $0 + $1.duration } / Double(workoutStore.records.count)
        return "\(Int(avg / 60))m"
    }
    
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
}

// MARK: - Supporting Components

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption).bold()
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct CompactWorkoutCard: View {
    let record: WorkoutRecord
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(record.start, format: .dateTime.day())
                    .font(.title3).bold()
                    .foregroundColor(.teal)
                Text(record.start, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 45)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.templateName ?? "Custom Workout")
                    .font(.subheadline).bold()
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Label("\(record.exercises.count)", systemImage: "list.bullet")
                    Label(formatDuration(record.duration), systemImage: "timer")
                    Label(String(format: "%.0f kg", record.totalVolume), systemImage: "scalemass")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes)m"
    }
}

struct AnalyticsNavButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).bold()
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
