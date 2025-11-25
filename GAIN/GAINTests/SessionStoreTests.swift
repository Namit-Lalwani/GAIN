import XCTest
@testable import GAIN

final class SessionStoreTests: XCTestCase {
    
    var sessionStore: SessionStore!
    
    override func setUp() {
        super.setUp()
        sessionStore = SessionStore.shared
    }
    
    override func tearDown() {
        sessionStore = nil
        super.tearDown()
    }
    
    // MARK: - START_SESSION Test
    func testStartSession() {
        let initialActiveId = sessionStore.activeSessionId
        
        let session = sessionStore.startSession()
        
        XCTAssertNotNil(sessionStore.activeSessionId)
        XCTAssertEqual(sessionStore.activeSessionId, session.id)
        XCTAssertEqual(session.status, .running)
        XCTAssertNotNil(sessionStore.sessions.first { $0.id == session.id })
        XCTAssertNotEqual(initialActiveId, sessionStore.activeSessionId)
    }
    
    // MARK: - PAUSE_SESSION Test
    func testPauseSession() {
        let session = sessionStore.startSession()
        let initialRevision = session.revision
        
        sessionStore.pauseSession(session.id)
        
        let paused = sessionStore.sessions.first { $0.id == session.id }
        XCTAssertEqual(paused?.status, .paused)
        XCTAssertGreaterThan(paused?.revision ?? 0, initialRevision)
    }
    
    // MARK: - RESUME_SESSION Test
    func testResumeSession() {
        let session = sessionStore.startSession()
        sessionStore.pauseSession(session.id)
        
        sessionStore.resumeSession(session.id)
        
        let resumed = sessionStore.sessions.first { $0.id == session.id }
        XCTAssertEqual(resumed?.status, .running)
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
        XCTAssertEqual(ended?.status, .ended)
        XCTAssertNotNil(ended?.endedAt)
        XCTAssertNotNil(ended?.finalMetrics)
        XCTAssertNil(sessionStore.activeSessionId) // Should clear active session
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
        XCTAssertEqual(updated?.metrics.count, initialMetricCount + 1)
        XCTAssertGreaterThan(updated?.revision ?? 0, initialRevision)
        
        let lastMetric = updated?.metrics.last
        XCTAssertEqual(lastMetric?.heartRate, 150)
        XCTAssertEqual(lastMetric?.power, 250)
        XCTAssertEqual(lastMetric?.cadence, 90)
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
        // Higher revision should win
        XCTAssertEqual(merged?.revision, 6)
        XCTAssertEqual(merged?.status, .ended)
    }
}





