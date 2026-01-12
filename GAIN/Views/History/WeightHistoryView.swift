import SwiftUI
import Charts

struct WeightHistoryView: View {
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var bodyProfileStore: BodyProfileStore
    
    @State private var weightText: String = ""
    @State private var entryDate: Date = Date()
    
    private var sortedEntries: [WeightEntry] {
        weightStore.entries.sorted { $0.date < $1.date }
    }
    
    private var latestEntry: WeightEntry? {
        weightStore.entries.first
    }
    
    private var averageWeight: Double? {
        guard !sortedEntries.isEmpty else { return nil }
        let total = sortedEntries.reduce(0.0) { $0 + $1.weight }
        return total / Double(sortedEntries.count)
    }
    
    private var minWeight: Double? {
        sortedEntries.map { $0.weight }.min()
    }
    
    private var maxWeight: Double? {
        sortedEntries.map { $0.weight }.max()
    }
    
    private var change7Days: Double? {
        guard let last = latestEntry else { return nil }
        let calendar = Calendar.current
        guard let fromDate = calendar.date(byAdding: .day, value: -7, to: last.date) else { return nil }
        let window = sortedEntries.filter { $0.date >= fromDate && $0.date <= last.date }
        guard let first = window.first, let lastInWindow = window.last else { return nil }
        return lastInWindow.weight - first.weight
    }
    
    private var change30Days: Double? {
        guard let last = latestEntry else { return nil }
        let calendar = Calendar.current
        guard let fromDate = calendar.date(byAdding: .day, value: -30, to: last.date) else { return nil }
        let window = sortedEntries.filter { $0.date >= fromDate && $0.date <= last.date }
        guard let first = window.first, let lastInWindow = window.last else { return nil }
        return lastInWindow.weight - first.weight
    }
    
    private var bmi: Double? {
        guard let latest = latestEntry else { return nil }
        let heightCm = bodyProfileStore.profile.heightCm
        guard heightCm > 0 else { return nil }
        let heightM = heightCm / 100.0
        guard heightM > 0 else { return nil }
        return latest.weight / (heightM * heightM)
    }
    
    var body: some View {
        List {
            Section {
                logSection
            }
            
            Section("Overview") {
                overviewSection
            }
            
            if #available(iOS 16.0, *) {
                Section("Weight Trend") {
                    trendChartSection
                }
            }
            
            Section("History") {
                historySection
            }
        }
        .navigationTitle("Body Weight")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if weightText.isEmpty, let latest = latestEntry {
                weightText = String(format: "%.1f", latest.weight)
            }
        }
    }
    
    private var logSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Weight", text: $weightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("kg")
                    .foregroundColor(.secondary)
            }
            
            DatePicker("Date", selection: $entryDate, displayedComponents: [.date])
                .datePickerStyle(.compact)
            
            Button(action: addEntry) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Log Weight")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(parsedWeight() == nil)
        }
    }
    
    private var overviewSection: some View {
        Group {
            if let latest = latestEntry {
                HStack {
                    Text("Latest")
                    Spacer()
                    Text(String(format: "%.1f kg", latest.weight))
                        .bold()
                }
                HStack {
                    Text("Recorded on")
                    Spacer()
                    Text(latest.date, style: .date)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No weight entries yet")
                    .foregroundColor(.secondary)
            }
            
            if let avg = averageWeight {
                HStack {
                    Text("Average (all time)")
                    Spacer()
                    Text(String(format: "%.1f kg", avg))
                        .bold()
                }
            }
            
            if let min = minWeight, let max = maxWeight {
                HStack {
                    Text("Range")
                    Spacer()
                    Text(String(format: "%.1f – %.1f kg", min, max))
                        .bold()
                }
            }
            
            if let delta7 = change7Days {
                HStack {
                    Text("Change (7 days)")
                    Spacer()
                    Text(formattedDelta(delta7))
                        .bold()
                }
            }
            
            if let delta30 = change30Days {
                HStack {
                    Text("Change (30 days)")
                    Spacer()
                    Text(formattedDelta(delta30))
                        .bold()
                }
            }
            
            if let bmiValue = bmi {
                HStack {
                    Text("BMI (latest)")
                    Spacer()
                    Text(String(format: "%.1f", bmiValue))
                        .bold()
                }
            }
        }
    }
    
    @available(iOS 16.0, *)
    private var trendChartSection: some View {
        Group {
            if sortedEntries.isEmpty {
                Text("No data yet to show a trend")
                    .foregroundColor(.secondary)
            } else {
                Chart {
                    ForEach(sortedEntries, id: \.id) { entry in
                        LineMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(.pink)
                        
                        PointMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Weight", entry.weight)
                        )
                        .foregroundStyle(.pink)
                    }
                }
                .frame(height: 220)
            }
        }
    }
    
    private var historySection: some View {
        Group {
            if weightStore.entries.isEmpty {
                Text("No weight entries logged yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(weightStore.entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%.1f kg", entry.weight))
                                .font(.headline)
                            Text(entry.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete(perform: deleteEntries)
            }
        }
    }
    
    private func parsedWeight() -> Double? {
        let cleaned = weightText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }
    
    private func addEntry() {
        guard let value = parsedWeight() else { return }
        let newEntry = WeightEntry(date: entryDate, weight: value)
        weightStore.add(newEntry)
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            let entry = weightStore.entries[index]
            weightStore.delete(id: entry.id)
        }
    }
    
    private func formattedDelta(_ value: Double) -> String {
        if value == 0 { return "0.0 kg" }
        let sign = value > 0 ? "+" : ""
        return String(format: "%@%.1f kg", sign, value)
    }
}

#Preview {
    NavigationStack {
        WeightHistoryView()
            .environmentObject(WeightStore.shared)
            .environmentObject(BodyProfileStore())
    }
}
