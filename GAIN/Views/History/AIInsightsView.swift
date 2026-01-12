import SwiftUI
import Charts

struct AIInsightsView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var selectedTimeframe: Timeframe = .month
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
        
        var id: String { self.rawValue }
    }
    
    private var filteredWorkouts: [WorkoutRecord] {
        let now = Date()
        let calendar = Calendar.current

        return workoutStore.records.filter { workout in
            switch selectedTimeframe {
            case .week:
                return calendar.isDate(workout.start, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(workout.start, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(workout.start, equalTo: now, toGranularity: .year)
            case .all:
                return true
            }
        }
    }

    private var filteredSessions: [WorkoutSession] {
        let now = Date()
        let calendar = Calendar.current

        return sessionStore.sessions.filter { session in
            let date = session.startedAt
            switch selectedTimeframe {
            case .week:
                return calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(date, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(date, equalTo: now, toGranularity: .year)
            case .all:
                return true
            }
        }
    }

    private var volumeByWeek: [Date: Double] {
        var result: [Date: Double] = [:]
        let calendar = Calendar.current

        for workout in filteredWorkouts {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: workout.start))!
            result[weekStart, default: 0] += workout.totalVolume
        }

        return result
    }

    private var summaryStats: AnalyticsEngine.SummaryStats? {
        guard !filteredWorkouts.isEmpty else { return nil }
        return AnalyticsEngine.generateSummary(
            workouts: filteredWorkouts,
            sessions: filteredSessions
        )
    }

    private var rollingVolumeData: [(id: UUID, date: Date, volume: Double, movingAverage: Double)] {
        AnalyticsEngine.rollingVolume(workouts: filteredWorkouts, window: 4)
    }

    private var recentPRs: [AnalyticsEngine.PR] {
        Array(AnalyticsEngine.detectPRs(workouts: filteredWorkouts).prefix(5))
    }

    private var muscleGroupStats: [(group: String, volume: Double, sets: Int)] {
        AnalyticsEngine.volumeByMuscleGroup(workouts: filteredWorkouts)
    }

    private var intensityStats: [(intensity: AnalyticsEngine.SessionIntensity, count: Int)] {
        AnalyticsEngine.intensityBreakdown(workouts: filteredWorkouts)
    }

    private var bestExercisePRs: [(exercise: String, value: Double, date: Date)] {
        AnalyticsEngine.bestPRPerExercise(workouts: filteredWorkouts)
    }

    var body: some View {
        List {
            Section {
                Picker("Timeframe", selection: $selectedTimeframe) {
                    ForEach(Timeframe.allCases) { timeframe in
                        Text(timeframe.rawValue).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)
            }

            Section("Overview") {
                if let stats = summaryStats {
                    HStack {
                        Text("Workouts (last 7 days)")
                        Spacer()
                        Text("\(stats.last7DaysSessions)")
                            .bold()
                    }
                    HStack {
                        Text("Total workouts")
                        Spacer()
                        Text("\(stats.totalSessions)")
                            .bold()
                    }
                    HStack {
                        Text("Average volume")
                        Spacer()
                        Text(String(format: "%.0f kg", stats.averageVolume))
                            .bold()
                    }
                    if let rolling = stats.lastRollingAverage {
                        HStack {
                            Text("Rolling 4-session avg")
                            Spacer()
                            Text(String(format: "%.0f kg", rolling))
                                .bold()
                        }
                    }
                    HStack {
                        Text("Personal records")
                        Spacer()
                        Text("\(stats.totalPRs)")
                            .bold()
                    }
                    if stats.anomalies > 0 {
                        HStack {
                            Text("Anomalous sessions")
                            Spacer()
                            Text("\(stats.anomalies)")
                                .bold()
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Text("Not enough data yet")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Workout Volume") {
                if !volumeByWeek.isEmpty {
                    Chart {
                        ForEach(Array(volumeByWeek.sorted(by: { $0.key < $1.key })), id: \.key) { date, volume in
                            BarMark(
                                x: .value("Week", date, unit: .weekOfYear),
                                y: .value("Volume", volume)
                            )
                            .foregroundStyle(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical)
                } else {
                    Text("No workout data available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }

            Section("Volume Trend") {
                let data = rollingVolumeData
                if !data.isEmpty {
                    Chart {
                        ForEach(data, id: \.id) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Volume", point.volume)
                            )
                            .foregroundStyle(.blue.opacity(0.4))

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Rolling Avg", point.movingAverage)
                            )
                            .foregroundStyle(.teal)
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical)
                } else {
                    Text("No volume data for this period")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }
            
            Section("Exercise Distribution") {
                if !filteredWorkouts.isEmpty {
                    ExerciseDistributionChart(workouts: filteredWorkouts)
                        .frame(height: 200)
                        .padding(.vertical)
                } else {
                    Text("No exercise data available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
            }

            Section("Personal Records") {
                let prs = recentPRs
                if prs.isEmpty {
                    Text("No PRs detected for this period")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    ForEach(prs) { pr in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pr.exerciseId ?? "Exercise")
                                    .font(.headline)
                                Text(pr.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f", pr.value))
                                .font(.headline)
                                .foregroundColor(.purple)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Muscle Groups") {
                let stats = muscleGroupStats
                if stats.isEmpty {
                    Text("No muscle group data for this period")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    Chart {
                        ForEach(stats.prefix(6), id: \.group) { item in
                            BarMark(
                                x: .value("Volume", item.volume),
                                y: .value("Group", item.group)
                            )
                            .foregroundStyle(.teal)
                        }
                    }
                    .frame(height: 200)
                    .padding(.vertical)
                }
            }

            Section("Intensity Breakdown") {
                let stats = intensityStats
                if stats.isEmpty {
                    Text("No intensity data for this period")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    Chart {
                        ForEach(stats, id: \.intensity) { item in
                            SectorMark(
                                angle: .value("Sessions", item.count),
                                innerRadius: .ratio(0.6),
                                angularInset: 1
                            )
                            .foregroundStyle(by: .value("Intensity", item.intensity.rawValue.capitalized))
                        }
                    }
                    .frame(height: 200)
                    .chartLegend(position: .bottom, alignment: .center)
                    .padding(.vertical)
                }
            }

            Section("Best PRs by Exercise") {
                let best = bestExercisePRs
                if best.isEmpty {
                    Text("No best PRs for this period")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                } else {
                    ForEach(best.prefix(5), id: \.exercise) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.exercise)
                                    .font(.headline)
                                Text(item.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(String(format: "%.0f", item.value))
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ExerciseDistributionChart: View {
    let workouts: [WorkoutRecord]
    
    private var exerciseCounts: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises {
                counts[exercise.name, default: 0] += 1
            }
        }
        
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    var body: some View {
        Chart {
            ForEach(exerciseCounts.prefix(5), id: \.name) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 1
                )
                .cornerRadius(4)
                .foregroundStyle(by: .value("Exercise", item.name))
            }
        }
        .chartLegend(position: .bottom, alignment: .center)
    }
}

#Preview {
    NavigationStack {
        AIInsightsView()
            .environmentObject(WorkoutStore.preview)
    }
}
