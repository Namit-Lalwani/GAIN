import SwiftUI

struct HomeView: View {
    @EnvironmentObject var waterStore: WaterStore
    @EnvironmentObject var calorieStore: CalorieStore
    @EnvironmentObject var stepsStore: StepsStore
    @EnvironmentObject var sleepStore: SleepStore
    @EnvironmentObject var goalsStore: GoalsStore

    // State for workout start modal and navigation
    @State private var showStartSheet = false
    @State private var selectedTemplate: WorkoutTemplate? = nil
    @State private var startWorkoutNow = false

    // Example templates - replace with your real store
    @State private var templates: [WorkoutTemplate] = [
        WorkoutTemplate(name: "Push Day", exercises: ["Bench Press", "Shoulder Press"]),
        WorkoutTemplate(name: "Leg Day", exercises: ["Squats", "Deadlifts"])
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Greeting + Date
                    VStack(alignment: .leading) {
                        Text("Hello, Athlete 👋")
                            .font(.title2).bold()
                        Text(Date(), style: .date)
                            .foregroundColor(.secondary)
                    }

                    // Quick Stats Row
                    HStack {
                        HomeQuickStat(title: "Calories", value: "\(calorieStore.caloriesToday)")
                        HomeQuickStat(title: "Water", value: "\(waterStore.waterToday) ml")
                        HomeQuickStat(title: "Steps", value: "\(stepsStore.stepsToday)")
                        HomeQuickStat(title: "Sleep", value: String(format: "%.1f h", sleepStore.sleepHours))
                    }

                    // Start Workout Button (Sheet Trigger)
                    Button {
                        showStartSheet = true
                    } label: {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke()
                            .frame(height: 80)
                            .overlay(
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Start Workout")
                                        .font(.title3).bold()
                                }
                                .padding()
                            )
                    }

                    // Navigation Link to open session
                    NavigationLink(
                        destination: WorkoutSessionView(template: selectedTemplate),
                        isActive: $startWorkoutNow,
                        label: { EmptyView() }
                    ).hidden()

                    // Quick Add Buttons
                    HStack(spacing: 12) {
                        HomeQuickButton(title: "Log Water") { }
                        HomeQuickButton(title: "Log Calories") { }
                        HomeQuickButton(title: "Log Weight") { }
                        HomeQuickButton(title: "Log Workout") { }
                    }

                    // Daily Progress Bars
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            DailyTile(title: "Water", progress: doubleSafe(waterStore.waterToday, goalsStore.dailyWaterGoal))
                            DailyTile(title: "Calories", progress: doubleSafe(calorieStore.caloriesToday, goalsStore.dailyCalorieGoal))
                            DailyTile(title: "Steps", progress: doubleSafe(stepsStore.stepsToday, goalsStore.dailyStepsGoal))
                        }
                        .padding(.vertical, 8)
                    }

                    RoundedRectangle(cornerRadius: 12)
                        .stroke()
                        .frame(height: 120)
                        .overlay(Text("Live Heart Rate Coming Soon"))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke()
                        .frame(height: 120)
                        .overlay(Text("Recent Workout Summary"))

                    RoundedRectangle(cornerRadius: 12)
                        .stroke()
                        .frame(height: 120)
                        .overlay(Text("AI Insight Coming Soon"))
                }
                .padding()
                .navigationTitle("Home")
            }
        }
        .sheet(isPresented: $showStartSheet) {
            WorkoutStartSheet(templates: templates) { chosenTemplate in
                selectedTemplate = chosenTemplate
                startWorkoutNow = true
                showStartSheet = false
            }
        }
    }

    private func doubleSafe(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0.0 }
        return min(Double(numerator) / Double(denominator), 1.0)
    }
}

// MARK: - Reusable Components
struct HomeQuickStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(value).bold()
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HomeQuickButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12)
                .stroke()
                .frame(height: 50)
                .overlay(Text(title).font(.subheadline).padding(.horizontal))
        }
        .frame(maxWidth: .infinity)
    }
}

struct DailyTile: View {
    let title: String
    let progress: Double

    var body: some View {
        VStack {
            Text(title).bold()
            ProgressView(value: progress)
                .frame(width: 100)
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).opacity(0.03))
    }
}
