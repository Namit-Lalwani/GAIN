import SwiftUI

struct WaterLoggerView: View {
    @EnvironmentObject var dailyStatsStore: DailyStatsStore
    @EnvironmentObject var waterIntakeStore: WaterIntakeStore
    
    @State private var customAmount: String = "250"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                quickContainers
                customAmountSection
                
                Divider()
                    .padding(.horizontal)
                
                todayList
                Spacer(minLength: 20)
            }
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Water")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Hydration")
                .font(.title2).bold()
            
            let current = waterIntakeStore.todayTotalMl
            let goal = dailyStatsStore.goals.dailyWater
            let progress = goal > 0 ? min(Double(current) / Double(goal), 1.0) : 0
            
            // Large progress circle
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 20)
                    .frame(width: 180, height: 180)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)
                
                VStack(spacing: 4) {
                    Text("\(current)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("ml")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("/ \(goal) ml")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            
            // Goal status
            HStack {
                Image(systemName: progress >= 1.0 ? "checkmark.circle.fill" : "drop.fill")
                    .foregroundColor(progress >= 1.0 ? .green : .blue)
                Text(progress >= 1.0 ? "Goal reached! Great job!" : "\(Int(progress * 100))% of daily goal")
                    .font(.subheadline)
                    .foregroundColor(progress >= 1.0 ? .green : .secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var quickContainers: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(waterIntakeStore.containers) { container in
                        Button {
                            waterIntakeStore.add(amountMl: container.volumeMl, containerName: container.name)
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: container.icon)
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                
                                Text(container.name)
                                    .font(.caption).bold()
                                    .foregroundColor(.primary)
                                Text("\(container.volumeMl) ml")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 90)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var customAmountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Amount")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                TextField("Amount", text: $customAmount)
                    .keyboardType(.numberPad)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                    .frame(maxWidth: .infinity)
                
                Text("ml")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Button {
                    if let value = Int(customAmount), value > 0 {
                        waterIntakeStore.add(amountMl: value)
                        customAmount = "250"
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private var todayList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's log")
                .font(.subheadline).bold()
                .padding(.horizontal)
            
            if waterIntakeStore.todayEntries.isEmpty {
                Text("No water logged yet today.")
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else {
                List {
                    ForEach(waterIntakeStore.todayEntries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(entry.amountMl) ml")
                                    .font(.headline)
                                if let name = entry.containerName {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        let entries = waterIntakeStore.todayEntries
                        for idx in indexSet {
                            let entry = entries[idx]
                            waterIntakeStore.delete(entry: entry)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }
}
