import Foundation

// MARK: - Persistence Adapter Protocol
public protocol PersistenceAdapter {
    func load() async throws -> AppState?
    func save(_ state: AppState) async throws
    func sync(_ local: AppState, applyMerged: @escaping (AppState) -> Void) async throws
}

// MARK: - App State
public struct AppState: Codable {
    private var _workouts: [String: WorkoutRecord]
    private var _sessions: [String: WorkoutSession]
    
    public var workouts: [UUID: WorkoutRecord] {
        get {
            Dictionary(uniqueKeysWithValues: _workouts.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }
        set {
            _workouts = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value) })
        }
    }
    
    public var sessions: [UUID: WorkoutSession] {
        get {
            Dictionary(uniqueKeysWithValues: _sessions.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else { return nil }
                return (uuid, value)
            })
        }
        set {
            _sessions = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value) })
        }
    }
    
    public var activeSessionId: UUID?
    public var lastSync: Date?
    
    public init(
        workouts: [UUID: WorkoutRecord] = [:],
        sessions: [UUID: WorkoutSession] = [:],
        activeSessionId: UUID? = nil,
        lastSync: Date? = nil
    ) {
        self._workouts = Dictionary(uniqueKeysWithValues: workouts.map { ($0.key.uuidString, $0.value) })
        self._sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.key.uuidString, $0.value) })
        self.activeSessionId = activeSessionId
        self.lastSync = lastSync
    }
    
    enum CodingKeys: String, CodingKey {
        case _workouts = "workouts"
        case _sessions = "sessions"
        case activeSessionId
        case lastSync
    }
}

// MARK: - Local Persistence Adapter
public struct LocalPersistenceAdapter: PersistenceAdapter {
    private let filename = "app_state.json"
    
    public init() {}
    
    public func load() async throws -> AppState? {
        let url = try fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppState.self, from: data)
    }
    
    public func save(_ state: AppState) async throws {
        let url = try fileURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: url, options: [.atomic])
    }
    
    public func sync(_ local: AppState, applyMerged: @escaping (AppState) -> Void) async throws {
        // For local-only, just apply local state
        applyMerged(local)
    }
    
    private func fileURL() throws -> URL {
        let fm = FileManager.default
        let doc = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return doc.appendingPathComponent(filename)
    }
}

// MARK: - Supabase Persistence Adapter (stub for future implementation)
public struct SupabasePersistenceAdapter: PersistenceAdapter {
    private let url: String
    private let key: String
    
    public init(url: String, key: String) {
        self.url = url
        self.key = key
    }
    
    public func load() async throws -> AppState? {
        // TODO: Implement Supabase client
        // let client = createSupabaseClient(url: url, key: key)
        // let response = try await client.from("user_state").select("state").eq("id", "local_user").single()
        // return response.data?.state
        throw SyncError.notImplemented
    }
    
    public func save(_ state: AppState) async throws {
        // TODO: Implement Supabase upsert
        // let client = createSupabaseClient(url: url, key: key)
        // try await client.from("user_state").upsert(["id": "local_user", "state": state])
        throw SyncError.notImplemented
    }
    
    public func sync(_ local: AppState, applyMerged: @escaping (AppState) -> Void) async throws {
        // TODO: Implement sync logic
        // 1. Push local to remote
        // 2. Pull remote
        // 3. Merge using conflict resolution
        // 4. Apply merged state
        throw SyncError.notImplemented
    }
}

// MARK: - Sync Errors
public enum SyncError: Error {
    case notImplemented
    case networkError
    case conflictResolutionFailed
}

// MARK: - Conflict Resolution Helper
public func mergeAppStates(local: AppState, remote: AppState) -> AppState {
    // Merge workouts (remote wins for conflicts)
    var mergedWorkouts = remote.workouts
    for (id, workout) in local.workouts {
        if mergedWorkouts[id] == nil {
            mergedWorkouts[id] = workout
        }
    }
    
    // Merge sessions using revision-based conflict resolution
    var mergedSessions: [UUID: WorkoutSession] = [:]
    let allSessionIds = Set(local.sessions.keys).union(Set(remote.sessions.keys))
    
    for id in allSessionIds {
        let localSession = local.sessions[id]
        let remoteSession = remote.sessions[id]
        
        if let local = localSession, let remote = remoteSession {
            // Higher revision wins
            if remote.revision > local.revision {
                mergedSessions[id] = remote
            } else if local.revision > remote.revision {
                mergedSessions[id] = local
            } else {
                // Same revision: prefer ended sessions
                if local.status == .ended && remote.status != .ended {
                    mergedSessions[id] = local
                } else if remote.status == .ended && local.status != .ended {
                    mergedSessions[id] = remote
                } else {
                    // Default to local
                    mergedSessions[id] = local
                }
            }
        } else if let local = localSession {
            mergedSessions[id] = local
        } else if let remote = remoteSession {
            mergedSessions[id] = remote
        }
    }
    
    return AppState(
        workouts: mergedWorkouts,
        sessions: mergedSessions,
        activeSessionId: local.activeSessionId ?? remote.activeSessionId,
        lastSync: Date()
    )
}

