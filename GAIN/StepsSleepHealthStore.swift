import Foundation
import HealthKit
import Combine

@MainActor
final class StepsSleepHealthStore: ObservableObject {
    static let shared = StepsSleepHealthStore()
    
    @Published private(set) var stepsToday: Int = 0
    @Published private(set) var sleepHoursToday: Double = 0
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var errorMessage: String?
    
    private let healthStore = HKHealthStore()
    
    private init() {
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit not available on this device"
            return
        }
        
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            errorMessage = "Unable to create HealthKit types for steps/sleep"
            return
        }
        
        let typesToRead: Set<HKObjectType> = [stepsType, sleepType]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            Task { @MainActor in
                if success {
                    StepsSleepHealthStore.shared.isAuthorized = true
                    StepsSleepHealthStore.shared.syncToday()
                } else {
                    StepsSleepHealthStore.shared.errorMessage = error?.localizedDescription ?? "Authorization failed"
                }
            }
        }
    }
    
    // MARK: - Public Sync API
    
    /// Call this on app foreground or manual refresh to pull today's steps and sleep
    nonisolated func syncToday() {
        fetchTodaySteps { steps in
            Task { @MainActor in
                StepsSleepHealthStore.shared.stepsToday = steps
                DailyStatsStore.shared.updateSteps(steps)
            }
        }
        
        fetchTodaySleepHours { hours in
            Task { @MainActor in
                StepsSleepHealthStore.shared.sleepHoursToday = hours
                DailyStatsStore.shared.updateSleep(hours)
            }
        }
    }
    
    // MARK: - Steps
    
    private nonisolated func fetchTodaySteps(completion: @escaping (Int) -> Void) {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0)
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepsType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, error in
            var total = 0
            if let quantity = stats?.sumQuantity() {
                let steps = quantity.doubleValue(for: HKUnit.count())
                total = Int(steps)
            }
            completion(total)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Sleep
    
    private nonisolated func fetchTodaySleepHours(completion: @escaping (Double) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(0)
            return
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: sleepType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { _, samples, error in
            guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                completion(0)
                return
            }
            
            var totalSeconds: TimeInterval = 0
            for sample in samples {
                // Count only actual sleep segments (iOS 16+ sleep analysis values)
                // Note: .asleep is deprecated in iOS 16.0, using specific sleep stage values instead
                let sleepValue = sample.value
                if sleepValue == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    sleepValue == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    sleepValue == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                    sleepValue == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                    totalSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                }
            }
            let hours = totalSeconds / 3600.0
            completion(hours)
        }
        
        healthStore.execute(query)
    }
}
