import SwiftUI

// MARK: - Sparkline View
struct SparklineView: View {
    let values: [Double]
    let color: Color
    
    init(values: [Double], color: Color = .blue) {
        self.values = values
        self.color = color
    }
    
    var body: some View {
        GeometryReader { geometry in
            if values.isEmpty {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
            } else {
                let max = values.max() ?? 1.0
                let min = values.min() ?? 0.0
                let range = max - min

                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) / CGFloat(Swift.max(values.count - 1, 1)) * geometry.size.width
                        let normalized = range > 0 ? (value - min) / range : 0.5
                        let y = geometry.size.height - (normalized * geometry.size.height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: 30)
    }
}

// MARK: - AI Insights View
struct AIInsightsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var sessionStore: SessionStore
    @State private var aiSummary: String?
    @State private var isLoadingSummary = false
    
    // Cached analytics to prevent recalculation on every render
    @State private var cachedStats: AnalyticsEngine.SummaryStats?
    @State private var cachedSessionsByDay: [(date: String, count: Int)] = []
    @State private var cachedRollingVolume: [(id: UUID, date: Date, volume: Double, movingAverage: Double)] = []
    @State private var lastWorkoutCount: Int = 0
    @State private var lastSessionCount: Int = 0
    
    private var stats: AnalyticsEngine.SummaryStats {
        if let cached = cachedStats {
            return cached
        }
        let computed = AnalyticsEngine.generateSummary(
            workouts: workoutStore.records,
            sessions: sessionStore.sessions
        )
        cachedStats = computed
        return computed
    }
    
    private var sessionsByDay: [(date: String, count: Int)] {
        if !cachedSessionsByDay.isEmpty {
            return cachedSessionsByDay
        }
        let result = AnalyticsEngine.sessionsPerDay(sessions: sessionStore.sessions, days: 21)
        let final = result.isEmpty ? Array(repeating: (date: "", count: 0), count: 21) : result
        cachedSessionsByDay = final
        return final
    }
    
    private var rollingVolume: [(id: UUID, date: Date, volume: Double, movingAverage: Double)] {
        if !cachedRollingVolume.isEmpty {
            return cachedRollingVolume
        }
        let result = AnalyticsEngine.rollingVolume(workouts: workoutStore.records, window: 4)
        cachedRollingVolume = result
        return result
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                
                if workoutStore.records.isEmpty && sessionStore.sessions.isEmpty {
                    emptyStateView
                } else {
                    chartsSection
                    prsSection
                    anomaliesSection
                    summarySection
                }
            }
            .padding()
        }
        .navigationTitle("AI Insights")
        .onAppear {
            updateCachedAnalytics()
            loadAISummary()
        }
        .onChange(of: workoutStore.records.count) { oldValue, newValue in
            if oldValue != newValue {
                updateCachedAnalytics()
            }
        }
        .onChange(of: sessionStore.sessions.count) { oldValue, newValue in
            if oldValue != newValue {
                updateCachedAnalytics()
            }
        }
    }
    
    private func updateCachedAnalytics() {
        // Only recalculate if data actually changed
        let currentWorkoutCount = workoutStore.records.count
        let currentSessionCount = sessionStore.sessions.count
        
        guard currentWorkoutCount != lastWorkoutCount || currentSessionCount != lastSessionCount else {
            return
        }
        
        lastWorkoutCount = currentWorkoutCount
        lastSessionCount = currentSessionCount
        
        // Clear cache
        cachedStats = nil
        cachedSessionsByDay = []
        cachedRollingVolume = []
        
        // Recalculate immediately (on main thread since we're already @MainActor)
        cachedStats = AnalyticsEngine.generateSummary(
            workouts: workoutStore.records,
            sessions: sessionStore.sessions
        )
        let sessionsResult = AnalyticsEngine.sessionsPerDay(sessions: sessionStore.sessions, days: 21)
        cachedSessionsByDay = sessionsResult.isEmpty ? Array(repeating: (date: "", count: 0), count: 21) : sessionsResult
        cachedRollingVolume = AnalyticsEngine.rollingVolume(workouts: workoutStore.records, window: 4)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No data yet")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Complete some workouts to see insights and analytics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History & AI Insights")
                .font(.title2)
                .bold()
            
            Text("Last updated: \(Date().formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Charts
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trends")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Sessions per day
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sessions (21 days)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !sessionsByDay.isEmpty {
                        SparklineView(
                            values: sessionsByDay.map { Double($0.count) },
                            color: .blue
                        )
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 30)
                    }
                    
                    Text("Last 7 days: \(stats.last7DaysSessions)")
                        .font(.caption)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                
                // Volume rolling average
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volume (rolling avg)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !rollingVolume.isEmpty {
                        SparklineView(
                            values: rollingVolume.map { $0.movingAverage },
                            color: .green
                        )
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 30)
                    }
                    
                    if let lastRolling = stats.lastRollingAverage {
                        Text("Latest: \(Int(lastRolling)) vol")
                            .font(.caption)
                            .bold()
                    } else {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - PRs Section
    private var prsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personal Records")
                    .font(.headline)
                
                Spacer()
                
                if !stats.recentPRs.isEmpty {
                    Text("\(stats.totalPRs) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if stats.recentPRs.isEmpty {
                Text("No PRs detected yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(stats.recentPRs) { pr in
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseId ?? "Exercise")
                                .font(.subheadline)
                                .bold()
                            
                            Text("\(Int(pr.value)) vol • \(pr.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Anomalies Section
    private var anomaliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Anomaly Detection")
                    .font(.headline)
                
                Spacer()
                
                if stats.anomalies > 0 {
                    Text("\(stats.anomalies) flagged")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            if stats.anomalies == 0 {
                Text("No anomalies detected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("\(stats.anomalies) session(s) with unusual volume patterns detected")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Summary Section
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Summary")
                .font(.headline)
            
            if isLoadingSummary {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let summary = aiSummary {
                Text(summary)
                    .font(.subheadline)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI summary disabled or not available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Enable by setting AI_SUMMARY_ENABLED=true in environment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Quick stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Stats")
                    .font(.subheadline)
                    .bold()
                
                StatRow(label: "Total Sessions", value: "\(stats.totalSessions)")
                StatRow(label: "Average Volume", value: String(format: "%.0f", stats.averageVolume))
                StatRow(label: "Total PRs", value: "\(stats.totalPRs)")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    // MARK: - AI Summary Loading
    private func loadAISummary() {
        let enabled = ProcessInfo.processInfo.environment["AI_SUMMARY_ENABLED"] == "true"
        guard enabled else { return }
        
        isLoadingSummary = true
        
        // Prepare payload
        let payload: [String: Any] = [
            "totalSessions": stats.totalSessions,
            "last7": stats.last7DaysSessions,
            "prsCount": stats.totalPRs,
            "lastRolling": stats.lastRollingAverage ?? 0,
            "anomalies": stats.anomalies
        ]
        
        // TODO: Replace with your backend URL
        guard let url = URL(string: "https://your-backend.com/api/ai/summary") else {
            isLoadingSummary = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            isLoadingSummary = false
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let summary = json["summary"] as? String {
                    await MainActor.run {
                        self.aiSummary = summary
                        self.isLoadingSummary = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingSummary = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingSummary = false
                }
            }
        }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

// MARK: - Preview
struct AIInsightsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AIInsightsView()
                .environmentObject(WorkoutStore.shared)
                .environmentObject(SessionStore.shared)
        }
    }
}

