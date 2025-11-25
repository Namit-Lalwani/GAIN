import Foundation
import HealthKit
import Combine

final class HealthKitManager: NSObject, ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?

    @Published var heartRate: Double = 0.0       // bpm
    @Published var activeEnergy: Double = 0.0    // kcal
    @Published var isTracking: Bool = false

    private var cancellables = Set<AnyCancellable>()

    @available(iOS 16.0, *)
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // MARK: - Authorization
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let typesToShare: Set = [
            HKObjectType.workoutType()
        ]

        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType()
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            completion(success)
        }
    }

    // MARK: - Start Workout
    @available(iOS 16.0, *)
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }
            workoutSession?.startActivity(with: Date())

            isTracking = true
        } catch {
            print("Failed to start workout: \(error)")
        }
    }

    // MARK: - End Workout
    @available(iOS 16.0, *)
    func endWorkout() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { success, error in
            self.workoutBuilder?.finishWorkout { _, _ in }
        }
        isTracking = false
    }
}
