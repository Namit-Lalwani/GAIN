import SwiftUI
import Charts

struct DailyStatsHistoryView: View {
    @EnvironmentObject var dailyStatsStore: DailyStatsStore
    @State private var selectedMetric: MetricType = .water
    
    enum MetricType: String, CaseIterable {
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
        
        var color: Color {
            switch self {
            case .water: return .blue
            case .calories: return .orange
            case .steps: return .green
            case .sleep: return .purple
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Metric Selector
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Label(metric.rawValue, systemImage: metric.icon)
                            .tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Chart
                if #available(iOS 16.0, *) {
                    Chart {
                        ForEach(dailyStatsStore.statsHistory.prefix(30).reversed(), id: \.id) { stat in
                            LineMark(
                                x: .value("Date", stat.date, unit: .day),
                                y: .value("Value", valueFor(stat: stat))
                            )
                            .foregroundStyle(selectedMetric.color)
                            .symbol(Circle())
                            
                            AreaMark(
                                x: .value("Date", stat.date, unit: .day),
                                y: .value("Value", valueFor(stat: stat))
                            )
                            .foregroundStyle(selectedMetric.color.opacity(0.2))
                        }
                    }
                    .frame(height: 250)
                    .padding()
                }
                
                // Stats List
                ForEach(dailyStatsStore.statsHistory.prefix(30), id: \.id) { stat in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(stat.date, style: .date)
                                .font(.headline)
                            Text(stat.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            HStack {
                                Image(systemName: selectedMetric.icon)
                                    .foregroundColor(selectedMetric.color)
                                Text(formattedValue(stat: stat))
                                    .font(.title3)
                                    .bold()
                            }
                            ProgressView(value: progressFor(stat: stat))
                                .tint(selectedMetric.color)
                                .frame(width: 100)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("\(selectedMetric.rawValue) History")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func valueFor(stat: DailyStats) -> Double {
        switch selectedMetric {
        case .water: return Double(stat.water)
        case .calories: return Double(stat.calories)
        case .steps: return Double(stat.steps)
        case .sleep: return stat.sleep
        }
    }
    
    private func formattedValue(stat: DailyStats) -> String {
        switch selectedMetric {
        case .water: return "\(stat.water) ml"
        case .calories: return "\(stat.calories) kcal"
        case .steps: return "\(stat.steps)"
        case .sleep: return String(format: "%.1f h", stat.sleep)
        }
    }
    
    private func progressFor(stat: DailyStats) -> Double {
        switch selectedMetric {
        case .water:
            return min(Double(stat.water) / Double(dailyStatsStore.goals.dailyWater), 1.0)
        case .calories:
            return min(Double(stat.calories) / Double(dailyStatsStore.goals.dailyCalories), 1.0)
        case .steps:
            return min(Double(stat.steps) / Double(dailyStatsStore.goals.dailySteps), 1.0)
        case .sleep:
            return min(stat.sleep / dailyStatsStore.goals.dailySleep, 1.0)
        }
    }
}
