import SwiftUI

struct LogDataSheet: View {
    @EnvironmentObject var dailyStatsStore: DailyStatsStore
    @Environment(\.dismiss) var dismiss

    let type: HomeView.LogType
    @State private var value: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundColor(Color.teal)
                        TextField("Enter value", text: $value)
                            .keyboardType(type == .sleep ? .decimalPad : .numberPad)
                    }
                } header: {
                    Text("\(type.rawValue) (\(type.unit))")
                }

                Section {
                    HStack {
                        Text("Current")
                        Spacer()
                        Text(currentValueFormatted)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Goal")
                        Spacer()
                        Text(goalValueFormatted)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Today's Stats")
                }
            }
            .navigationTitle("Log \(type.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveData()
                    }
                    .disabled(value.isEmpty)
                }
            }
            .onAppear {
                value = getCurrentValue()
            }
        }
    }

    private func getCurrentValue() -> String {
        switch type {
        case .water:
            return "\(dailyStatsStore.todayStats.water)"
        case .calories:
            return "\(dailyStatsStore.todayStats.calories)"
        case .steps:
            return "\(dailyStatsStore.todayStats.steps)"
        case .sleep:
            return String(format: "%.1f", dailyStatsStore.todayStats.sleep)
        }
    }

    private var currentValueFormatted: String {
        switch type {
        case .water:
            return "\(dailyStatsStore.todayStats.water) \(type.unit)"
        case .calories:
            return "\(dailyStatsStore.todayStats.calories) \(type.unit)"
        case .steps:
            return "\(dailyStatsStore.todayStats.steps) \(type.unit)"
        case .sleep:
            return String(format: "%.1f \(type.unit)", dailyStatsStore.todayStats.sleep)
        }
    }

    private var goalValueFormatted: String {
        switch type {
        case .water:
            return "\(dailyStatsStore.goals.dailyWater) \(type.unit)"
        case .calories:
            return "\(dailyStatsStore.goals.dailyCalories) \(type.unit)"
        case .steps:
            return "\(dailyStatsStore.goals.dailySteps) \(type.unit)"
        case .sleep:
            return String(format: "%.1f \(type.unit)", dailyStatsStore.goals.dailySleep)
        }
    }

    private func saveData() {
        switch type {
        case .water:
            if let intValue = Int(value) {
                dailyStatsStore.updateWater(intValue)
            }
        case .calories:
            if let intValue = Int(value) {
                dailyStatsStore.updateCalories(intValue)
            }
        case .steps:
            if let intValue = Int(value) {
                dailyStatsStore.updateSteps(intValue)
            }
        case .sleep:
            if let doubleValue = Double(value) {
                dailyStatsStore.updateSleep(doubleValue)
            }
        }
        dismiss()
    }
}
