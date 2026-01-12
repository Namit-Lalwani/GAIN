import XCTest
@testable import GAIN

@MainActor
final class SessionStoreTests: XCTestCase {
    
    var sessionStore: SessionStore!
    
    override func setUp() async throws {
        try await super.setUp()
        sessionStore = SessionStore.shared
    }
    
    override func tearDown() async throws {
        sessionStore = nil
        try await super.tearDown()
    }
    
    // MARK: - START_SESSION Test
    func testStartSession() {
        let initialActiveId = sessionStore.activeSessionId
        
        let session = sessionStore.startSession()
        
        let activeSessionId = sessionStore.activeSessionId
        let foundSession = sessionStore.sessions.first { $0.id == session.id }
        
        XCTAssertNotNil(activeSessionId)
        XCTAssertEqual(activeSessionId, session.id)
        XCTAssertEqual(session.status, .running)
        XCTAssertNotNil(foundSession)
        XCTAssertNotEqual(initialActiveId, activeSessionId)
    }
    
    // MARK: - PAUSE_SESSION Test
    func testPauseSession() {
        let session = sessionStore.startSession()
        let initialRevision = session.revision
        
        sessionStore.pauseSession(session.id)
        
        let paused = sessionStore.sessions.first { $0.id == session.id }
        let pausedStatus = paused?.status
        let pausedRevision = paused?.revision ?? 0
        
        XCTAssertEqual(pausedStatus, .paused)
        XCTAssertGreaterThan(pausedRevision, initialRevision)
    }
    
    // MARK: - RESUME_SESSION Test
    func testResumeSession() {
        let session = sessionStore.startSession()
        sessionStore.pauseSession(session.id)
        
        sessionStore.resumeSession(session.id)
        
        let resumed = sessionStore.sessions.first { $0.id == session.id }
        let resumedStatus = resumed?.status
        XCTAssertEqual(resumedStatus, .running)
    }
    
    // MARK: - END_SESSION Test
    func testEndSession() {
        let session = sessionStore.startSession()
        let sessionId = session.id
        
        let finalMetrics: [String: AnyCodable] = [
            "duration": AnyCodable(3600),
            "totalVolume": AnyCodable(5000.0)
        ]
        
        sessionStore.endSession(sessionId, finalMetrics: finalMetrics)
        
        let ended = sessionStore.sessions.first { $0.id == sessionId }
        let activeSessionId = sessionStore.activeSessionId
        let endedStatus = ended?.status
        let endedAt = ended?.endedAt
        let finalMetricsResult = ended?.finalMetrics
        
        XCTAssertEqual(endedStatus, .ended)
        XCTAssertNotNil(endedAt)
        XCTAssertNotNil(finalMetricsResult)
        XCTAssertNil(activeSessionId) // Should clear active session
    }
    
    // MARK: - LOG_METRICS Test
    func testLogMetrics() {
        let session = sessionStore.startSession()
        let initialMetricCount = session.metrics.count
        let initialRevision = session.revision
        
        sessionStore.logMetric(
            sessionId: session.id,
            heartRate: 150,
            power: 250,
            cadence: 90,
            secondsElapsed: 120
        )
        
        let updated = sessionStore.sessions.first { $0.id == session.id }
        let updatedMetricCount = updated?.metrics.count ?? 0
        let updatedRevision = updated?.revision ?? 0
        let lastMetric = updated?.metrics.last
        let lastMetricHeartRate = lastMetric?.heartRate
        let lastMetricPower = lastMetric?.power
        let lastMetricCadence = lastMetric?.cadence
        
        XCTAssertEqual(updatedMetricCount, initialMetricCount + 1)
        XCTAssertGreaterThan(updatedRevision, initialRevision)
        XCTAssertEqual(lastMetricHeartRate, 150)
        XCTAssertEqual(lastMetricPower, 250)
        XCTAssertEqual(lastMetricCadence, 90)
    }
    
    // MARK: - Conflict Resolution Test
    func testConflictResolution() {
        let localSession = WorkoutSession(
            id: UUID(),
            status: .running,
            revision: 5
        )
        
        let remoteSession = WorkoutSession(
            id: localSession.id,
            status: .ended,
            revision: 6
        )
        
        sessionStore.mergeSessions([remoteSession])
        
        let merged = sessionStore.sessions.first { $0.id == localSession.id }
        let mergedRevision = merged?.revision
        let mergedStatus = merged?.status
        // Higher revision should win
        XCTAssertEqual(mergedRevision, 6)
        XCTAssertEqual(mergedStatus, .ended)
    }
}





