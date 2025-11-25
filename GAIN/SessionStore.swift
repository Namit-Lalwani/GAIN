import Foundation
import Combine

@MainActor
public final class SessionStore: ObservableObject {
    public static let shared = SessionStore()
    
    @Published public private(set) var sessions: [WorkoutSession] = [] {
        didSet {
            // Prevent infinite save loops
            guard !isLoading else { return }
            // Debounce saves to prevent excessive I/O
            saveDebouncer.cancel()
            saveDebouncer = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    self?.performSave()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: saveDebouncer)
        }
    }
    
    private var saveDebouncer = DispatchWorkItem {}
    
    @Published public private(set) var activeSessionId: UUID?
    
    public var activeSession: WorkoutSession? {
        guard let activeSessionId = activeSessionId else { return nil }
        return sessions.first { $0.id == activeSessionId }
    }
    
    private let filename = "sessions.json"
    private var isLoading = false
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    private init() {
        // Initialize synchronously, load asynchronously after a brief delay
        // This prevents crashes during app startup
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                await self.performLoad()
            }
        }
    }
    
    // MARK: - Session Management
    public func startSession(workoutId: UUID? = nil) -> WorkoutSession {
        let session = WorkoutSession(
            workoutId: workoutId,
            startedAt: Date(),
            status: .running
        )
        // Safe array insertion
        if sessions.isEmpty {
            sessions = [session]
        } else {
            sessions.insert(session, at: 0)
        }
        activeSessionId = session.id
        return session
    }
    
    public func pauseSession(_ sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              index < sessions.count else { return }
        var updatedSession = sessions[index]
        updatedSession.status = .paused
        updatedSession.revision += 1
        sessions[index] = updatedSession
    }
    
    public func resumeSession(_ sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              index < sessions.count else { return }
        var updatedSession = sessions[index]
        updatedSession.status = .running
        updatedSession.revision += 1
        sessions[index] = updatedSession
    }
    
    public func endSession(_ sessionId: UUID, finalMetrics: [String: AnyCodable]? = nil) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              index < sessions.count else { return }
        var updatedSession = sessions[index]
        updatedSession.status = .ended
        updatedSession.endedAt = Date()
        updatedSession.finalMetrics = finalMetrics
        updatedSession.revision += 1
        sessions[index] = updatedSession
        
        if activeSessionId == sessionId {
            activeSessionId = nil
        }
    }
    
    // MARK: - Metrics
    public func logMetric(sessionId: UUID, metric: Metric) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              index < sessions.count else { return }
        var updatedSession = sessions[index]
        updatedSession.metrics.append(metric)
        updatedSession.revision += 1
        sessions[index] = updatedSession
    }
    
    public func logMetric(
        sessionId: UUID,
        heartRate: Double? = nil,
        power: Double? = nil,
        cadence: Double? = nil,
        secondsElapsed: TimeInterval? = nil,
        customData: [String: AnyCodable]? = nil
    ) {
        let metric = Metric(
            timestamp: Date(),
            heartRate: heartRate,
            power: power,
            cadence: cadence,
            secondsElapsed: secondsElapsed,
            customData: customData
        )
        logMetric(sessionId: sessionId, metric: metric)
    }
    
    // MARK: - CRUD
    public func deleteSession(_ sessionId: UUID) {
        sessions.removeAll { $0.id == sessionId }
        if activeSessionId == sessionId {
            activeSessionId = nil
        }
    }
    
    public func getSessions(for workoutId: UUID) -> [WorkoutSession] {
        sessions.filter { $0.workoutId == workoutId }
    }
    
    // MARK: - Persistence
    private func fileURL() throws -> URL {
        let fm = FileManager.default
        let doc = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return doc.appendingPathComponent(filename)
    }
    
    private func performSave() {
        guard !isLoading else { return }
        do {
            let url = try fileURL()
            let data = try encoder.encode(sessions)
            try data.write(to: url, options: [.atomic])
        } catch {
            // Log error but don't crash
            print("SessionStore save error:", error.localizedDescription)
        }
    }
    
    // Note: save() is not called directly - debouncing is handled in didSet
    
    @MainActor
    private func performLoad() async {
        isLoading = true
        defer {
            isLoading = false
        }
        
        do {
            let url = try fileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                sessions = []
                return
            }
            
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                sessions = []
                return
            }
            
            let decoded = try decoder.decode([WorkoutSession].self, from: data)
            sessions = decoded
            
            // Restore active session if it exists and is still running/paused
            if let active = decoded.first(where: { $0.status != .ended }) {
                activeSessionId = active.id
            }
        } catch {
            // Log error but don't crash - start with empty sessions
            print("SessionStore load error:", error.localizedDescription)
            sessions = []
            activeSessionId = nil
        }
    }
    
    // MARK: - Sync (stub for future backend integration)
    public func syncNow() async throws {
        // TODO: Implement sync with backend
        // This would:
        // 1. Push local sessions to backend
        // 2. Pull remote sessions
        // 3. Merge using conflict resolution (higher revision wins)
        // 4. Update local state
        print("Sync not yet implemented")
    }
    
    // MARK: - Conflict Resolution
    public func mergeSessions(_ remoteSessions: [WorkoutSession]) {
        guard !remoteSessions.isEmpty else { return }
        
        var merged: [WorkoutSession] = []
        var localDict: [UUID: WorkoutSession] = [:]
        
        // Safe dictionary building
        for session in sessions {
            localDict[session.id] = session
        }
        
        var remoteDict: [UUID: WorkoutSession] = [:]
        for session in remoteSessions {
            remoteDict[session.id] = session
        }
        
        let allIds = Set(localDict.keys).union(Set(remoteDict.keys))
        
        // Safe merging
        for id in allIds {
            let local = localDict[id]
            let remote = remoteDict[id]
            
            if let local = local, let remote = remote {
                // Conflict resolution: higher revision wins
                if remote.revision > local.revision {
                    merged.append(remote)
                } else if local.revision > remote.revision {
                    merged.append(local)
                } else {
                    // Same revision: prefer ended sessions
                    if local.status == .ended && remote.status != .ended {
                        merged.append(local)
                    } else if remote.status == .ended && local.status != .ended {
                        merged.append(remote)
                    } else {
                        // Default to local
                        merged.append(local)
                    }
                }
            } else if let local = local {
                merged.append(local)
            } else if let remote = remote {
                merged.append(remote)
            }
        }
        
        // Safe sorting
        sessions = merged.sorted { session1, session2 in
            session1.startedAt > session2.startedAt
        }
    }
}

