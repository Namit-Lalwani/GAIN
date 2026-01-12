import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

/// Synchronizes local data stores with Firebase Firestore.
@MainActor
class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    private lazy var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private let authManager = AuthManager.shared
    
    private init() {
        setupSubscriptions()
    }
    
    func setupSubscriptions() {
        // Observe WorkoutStore changes
        WorkoutStore.shared.$records
            .sink { [weak self] records in
                self?.syncWorkouts(records)
            }
            .store(in: &cancellables)
        
        // Observe DailyStatsStore changes
        DailyStatsStore.shared.$todayStats
            .sink { [weak self] stats in
                self?.syncDailyStats(stats)
            }
            .store(in: &cancellables)
        
        // Observe Auth changes to trigger full sync when logged in
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    self?.performFullSync()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Syncs workout records to Firestore under user's collection
    private func syncWorkouts(_ records: [WorkoutRecord]) {
        guard let userId = authManager.currentUser?.uid else { return }
        
        let batch = db.batch()
        let workoutsRef = db.collection("users").document(userId).collection("workouts")
        
        for record in records.prefix(50) { // Increased limit
            let docRef = workoutsRef.document(record.id.uuidString)
            
            do {
                let encodedData = try JSONEncoder().encode(record)
                let dictionary = try JSONSerialization.jsonObject(with: encodedData, options: []) as? [String: Any] ?? [:]
                batch.setData(dictionary, forDocument: docRef, merge: true)
            } catch {
                print("Error encoding workout for sync: \(error.localizedDescription)")
            }
        }
        
        batch.commit()
    }

    /// Syncs daily stats to Firestore
    private func syncDailyStats(_ stats: DailyStats) {
        guard let userId = authManager.currentUser?.uid else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: stats.date)
        
        let docRef = db.collection("users").document(userId).collection("dailyStats").document(dateKey)
        
        do {
            let encodedData = try JSONEncoder().encode(stats)
            let dictionary = try JSONSerialization.jsonObject(with: encodedData, options: []) as? [String: Any] ?? [:]
            docRef.setData(dictionary, merge: true)
        } catch {
            print("Error encoding daily stats for sync: \(error.localizedDescription)")
        }
    }
    
    func performFullSync() {
        guard let userId = authManager.currentUser?.uid else { return }
        print("Performing full sync for user: \(userId)")
        
        // Sync workouts
        syncWorkouts(WorkoutStore.shared.records)
        
        // Sync daily stats
        syncDailyStats(DailyStatsStore.shared.todayStats)
        
        // Sync profile
        authManager.syncUserProfile()
    }
}
