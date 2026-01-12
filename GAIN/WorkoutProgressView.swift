import SwiftUI
import Charts

struct WorkoutProgressView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @State private var selectedExercise: String = ""
    @State private var selectedMetric: Metric = .volume
    
    enum Metric: String, CaseIterable, Identifiable {
        case volume = "Volume"
        case reps = "Reps"
        case sets = "Sets"
        
        var id: String { self.rawValue }
    }
    
    private var exerciseNames: [String] {
        var names = Set<String>()
        for workout in workoutStore.records {
            for exercise in workout.exercises {
                names.insert(exercise.name)
            }
        }
        return Array(names).sorted()
    }
    
    private var exerciseData: [ExerciseDataPoint] {
        var data: [ExerciseDataPoint] = []
        
        for workout in workoutStore.records.sorted(by: { $0.start < $1.start }) {
            for exercise in workout.exercises {
                if !selectedExercise.isEmpty && exercise.name != selectedExercise { continue }
                
                let volume = exercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
                let reps = exercise.sets.reduce(0) { $0 + $1.reps }
                
                data.append(ExerciseDataPoint(
                    date: workout.start,
                    exercise: exercise.name,
                    volume: volume,
                    reps: reps,
                    sets: exercise.sets.count
                ))
            }
        }
        
        return data
    }
    
    private var chartData: [ExerciseDataPoint] {
        let grouped = Dictionary(grouping: exerciseData) { dataPoint in
            Calendar.current.startOfDay(for: dataPoint.date)
        }
        
        return grouped.map { date, points in
            ExerciseDataPoint(
                date: date,
                exercise: selectedExercise.isEmpty ? "All Exercises" : selectedExercise,
                volume: points.reduce(0) { $0 + $1.volume },
                reps: points.reduce(0) { $0 + $1.reps },
                sets: points.reduce(0) { $0 + $1.sets }
            )
        }.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        List {
            if !exerciseNames.isEmpty {
                Section {
                    Picker("Exercise", selection: $selectedExercise) {
                        Text("All Exercises").tag("")
                        ForEach(exerciseNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Metric", selection: $selectedMetric) {
                        ForEach(Metric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    if !chartData.isEmpty {
                        Chart {
                            ForEach(chartData) { data in
                                LineMark(
                                    x: .value("Date", data.date, unit: .day),
                                    y: .value(selectedMetric.rawValue, selectedMetricValue(for: data))
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(by: .value("Exercise", data.exercise))
                                .symbol(Circle().strokeBorder(lineWidth: 2))
                                
                                if exerciseNames.count <= 5 || !selectedExercise.isEmpty {
                                    PointMark(
                                        x: .value("Date", data.date, unit: .day),
                                        y: .value(selectedMetric.rawValue, selectedMetricValue(for: data))
                                    )
                                    .foregroundStyle(by: .value("Exercise", data.exercise))
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 250)
                        .padding(.vertical)
                    } else {
                        Text("No data available for selected exercise")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }
                
                Section("Summary") {
                    if !chartData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Progress Summary")
                                .font(.headline)
                            
                            if let first = chartData.first, let last = chartData.last {
                                let firstValue = selectedMetricValue(for: first)
                                let lastValue = selectedMetricValue(for: last)
                                let difference = lastValue - firstValue
                                let percentage = firstValue > 0 ? (difference / firstValue) * 100 : 0
                                
                                HStack {
                                    Text("Change:")
                                    Text(String(format: "%.1f%%", percentage))
                                        .foregroundColor(difference >= 0 ? .green : .red)
                                    Spacer()
                                    Text("\(firstValue.formatted()) → \(lastValue.formatted())")
                                }
                                .font(.subheadline)
                                
                                if difference != 0 {
                                    Text(difference > 0 ? "↑ Improving" : "↓ Needs attention")
                                        .font(.caption)
                                        .foregroundColor(difference > 0 ? .green : .red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Text("No exercise data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .navigationTitle("Exercise Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func selectedMetricValue(for data: ExerciseDataPoint) -> Double {
        switch selectedMetric {
        case .volume: return data.volume
        case .reps: return Double(data.reps)
        case .sets: return Double(data.sets)
        }
    }
}

// MARK: - Data Models
private struct ExerciseDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let exercise: String
    let volume: Double
    let reps: Int
    let sets: Int
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WorkoutProgressView()
            .environmentObject(WorkoutStore.preview)
    }
}
