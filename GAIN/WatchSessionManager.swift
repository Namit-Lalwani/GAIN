import Foundation
import WatchConnectivity
import HealthKit
import Combine
#if canImport(WatchKit)
import WatchKit
#endif

@MainActor
public class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSessionManager()

    private var session: WCSession?
    private var pendingPackets: [[String: Any]] = []

    @Published public var isReachable: Bool = false
    @Published public var activationState: WCSessionActivationState = .notActivated

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            activationState = session?.activationState ?? .notActivated
            isReachable = session?.isReachable ?? false
        }
    }

    // MARK: - WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = session.isReachable
        }
        if let e = error { print("WC activation error:", e) }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) { }
    public func sessionDidDeactivate(_ session: WCSession) { }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("Received message:", message)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(["ok": true])
    }

    public func session(_ session: WCSession, reachabilityDidChange isReachable: Bool) {
        Task { @MainActor in
            self.isReachable = isReachable
        }
    }
}




