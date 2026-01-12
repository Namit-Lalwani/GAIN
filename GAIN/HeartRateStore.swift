import Foundation
import HealthKit
import Combine

@MainActor
final class HeartRateStore: ObservableObject {
    static let shared = HeartRateStore()
    
    @Published var currentHeartRate: Int = 0
    @Published var isAvailable: Bool = false
    @Published var errorMessage: String?
    
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var anchor: HKQueryAnchor?
    
    private init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit not available on this device"
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { success, error in
            Task { @MainActor in
                if success {
                    self.startHeartRateQuery()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Authorization failed"
                }
            }
        }
    }
    
    func startHeartRateQuery() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Create anchored object query for continuous updates
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: anchor,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, newAnchor, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                self.anchor = newAnchor
                self.processHeartRateSamples(samples)
            }
        }
        
        // Set update handler for real-time updates
        heartRateQuery?.updateHandler = { [weak self] query, samples, deletedObjects, newAnchor, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                self.anchor = newAnchor
                self.processHeartRateSamples(samples)
            }
        }
        
        healthStore.execute(heartRateQuery!)
        
        // Enable background delivery for heart rate
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery error: \(error.localizedDescription)")
            }
        }
    }
    
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else {
            return
        }
        
        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let heartRate = lastSample.quantity.doubleValue(for: heartRateUnit)
        
        self.currentHeartRate = Int(heartRate)
        self.isAvailable = true
    }
    
    func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
    }
}
