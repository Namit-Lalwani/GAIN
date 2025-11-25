import SwiftUI

// MARK: - Exercise Progress Chart
struct ExerciseChartView: View {
    let exerciseName: String
    let workouts: [WorkoutRecord]
    
    // Cache computed data to prevent recalculation on every render
    @State private var cachedExerciseData: [(date: Date, weight: Double, reps: Int, volume: Double)] = []
    @State private var cachedRollingAverage: [Double] = []
    @State private var lastWorkoutsCount: Int = 0
    
    private var exerciseData: [(date: Date, weight: Double, reps: Int, volume: Double)] {
        if !cachedExerciseData.isEmpty && workouts.count == lastWorkoutsCount {
            return cachedExerciseData
        }
        
        var data: [(date: Date, weight: Double, reps: Int, volume: Double)] = []
        
        for workout in workouts.sorted(by: { $0.start < $1.start }) {
            if let exercise = workout.exercises.first(where: { $0.name == exerciseName }) {
                // Aggregate sets per workout session
                let totalVolume = exercise.sets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }
                let avgWeight = exercise.sets.isEmpty ? 0.0 : exercise.sets.map { $0.weight }.reduce(0.0, +) / Double(exercise.sets.count)
                let totalReps = exercise.sets.reduce(0) { $0 + $1.reps }
                
                data.append((
                    date: workout.start,
                    weight: avgWeight,
                    reps: totalReps,
                    volume: totalVolume
                ))
            }
        }
        
        cachedExerciseData = data
        lastWorkoutsCount = workouts.count
        return data
    }
    
    private var rollingAverage: [Double] {
        if !cachedRollingAverage.isEmpty && workouts.count == lastWorkoutsCount {
            return cachedRollingAverage
        }
        
        let volumes = exerciseData.map { $0.volume }
        var averages: [Double] = []
        let window = 4
        
        for i in 0..<volumes.count {
            let start = max(0, i - window + 1)
            let slice = Array(volumes[start...i])
            let avg = slice.reduce(0.0, +) / Double(slice.count)
            averages.append(avg)
        }
        
        cachedRollingAverage = averages
        return averages
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(exerciseName)
                .font(.title2)
                .bold()
            
            if exerciseData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No data available for this exercise")
                        .foregroundColor(.secondary)
                    Text("Complete workouts with this exercise to see progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Volume Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Volume Trend")
                        .font(.headline)
                    
                    // Volume chart using Sparkline
                    ZStack(alignment: .topLeading) {
                        SparklineView(
                            values: exerciseData.map { $0.volume },
                            color: .blue
                        )
                        .frame(height: 150)
                        
                        // Rolling average overlay
                        if !rollingAverage.isEmpty {
                            SparklineView(
                                values: rollingAverage,
                                color: .green
                            )
                            .frame(height: 150)
                            .opacity(0.6)
                        }
                    }
                    
                    // Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            Text("Volume")
                                .font(.caption)
                        }
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Moving Avg")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Stats
                HStack(spacing: 12) {
                    StatCard(
                        title: "Best Volume",
                        value: String(format: "%.0f", exerciseData.map { $0.volume }.max() ?? 0)
                    )
                    
                    StatCard(
                        title: "Avg Volume",
                        value: String(format: "%.0f", exerciseData.isEmpty ? 0 : exerciseData.map { $0.volume }.reduce(0, +) / Double(exerciseData.count))
                    )
                    
                    StatCard(
                        title: "Sessions",
                        value: "\(exerciseData.count)"
                    )
                }
                
                // Latest stats
                if let latest = exerciseData.last {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Session")
                            .font(.subheadline)
                            .bold()
                        HStack {
                            Text("Volume: \(Int(latest.volume))")
                            Spacer()
                            Text("Avg Weight: \(String(format: "%.1f", latest.weight)) kg")
                            Spacer()
                            Text("Total Reps: \(latest.reps)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        if !rollingAverage.isEmpty, let lastMA = rollingAverage.last {
                            Text("Moving Average (4): \(Int(lastMA))")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Exercise List View
struct ExerciseProgressView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    
    private var uniqueExercises: [String] {
        let allExercises = workoutStore.records.flatMap { $0.exercises.map { $0.name } }
        return Array(Set(allExercises)).sorted()
    }
    
    var body: some View {
        Group {
            if uniqueExercises.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No exercises found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Complete some workouts to see exercise progress")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(uniqueExercises, id: \.self) { exercise in
                        NavigationLink(destination: ExerciseChartView(exerciseName: exercise, workouts: workoutStore.records)) {
                            HStack {
                                Text(exercise)
                                    .font(.headline)
                                Spacer()
                                Text("\(workoutStore.records.filter { $0.exercises.contains(where: { $0.name == exercise }) }.count) sessions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercise Progress")
    }
}

