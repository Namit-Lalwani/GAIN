import Foundation
import Combine

final class WorkoutStore: ObservableObject {
    @Published var workouts: [Workout] = [] {
        didSet { save() }
    }

    private let filename = "workouts.json"

    init() {
        load()
    }

    func add(_ workout: Workout) {
        workouts.append(workout)
        workouts.sort { $0.date > $1.date }
    }

    func update(_ workout: Workout) {
        guard let i = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        workouts[i] = workout
    }

    func delete(_ workoutID: UUID) {
        workouts.removeAll { $0.id == workoutID }
    }

    private func save() {
        FileManager.save(workouts, to: filename)
    }

    private func load() {
        if let loaded: [Workout] = FileManager.load([Workout].self, from: filename) {
            self.workouts = loaded
        }
    }
}


final class WeightStore: ObservableObject {
    @Published var entries: [WeightEntry] = [] {
        didSet { save() }
    }

    private let filename = "weights.json"

    init() {
        load()
    }

    func add(_ entry: WeightEntry) {
        entries.append(entry)
        entries.sort { $0.date > $1.date }
    }

    func update(_ entry: WeightEntry) {
        guard let i = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[i] = entry
    }

    func delete(_ entryID: UUID) {
        entries.removeAll { $0.id == entryID }
    }

    private func save() {
        FileManager.save(entries, to: filename)
    }

    private func load() {
        if let loaded: [WeightEntry] = FileManager.load([WeightEntry].self, from: filename) {
            self.entries = loaded
        }
    }
}
