import Foundation
import WatchConnectivity
import Combine
import UIKit


@MainActor
public class iPhoneSessionReceiver: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = iPhoneSessionReceiver()

    private var session: WCSession?
    private var pendingPackets: [[String: Any]] = []
    private var isProcessingQueue = false

    @Published public var isReachable: Bool = false
    @Published public var activationState: WCSessionActivationState = .notActivated

    // Replace with your real backend endpoint
    private let ingestURLString = "https://YOUR_BACKEND_DOMAIN/api/sessions/ingest"

    private override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            self.activationState = session?.activationState ?? .notActivated
            self.isReachable = session?.isReachable ?? false
        }
        // try to flush any previously pending packets (if persisted)
        Task { await processQueueIfNeeded() }
    }

    // MARK: - WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = session.isReachable
        }
        if let e = error { print("WC activation error (iPhone):", e) }
        Task { await processQueueIfNeeded() }
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {
        // handle transition if necessary
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        // If needed: session.activate() on the new session
        // For iPhone typically re-activate: session.activate()
        session.activate()
    }

    // Basic message receiver (no reply)
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("iPhone received message:", message)
        enqueuePacket(message)
    }

    // Message receiver with optional reply handler
    public func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("iPhone received message with replyHandler:", message)
        enqueuePacket(message)
        // quick ack
        replyHandler(["ok": true])
    }

    // userInfo (background transfer) — useful for larger batches
    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("iPhone received userInfo:", userInfo)
        enqueuePacket(userInfo)
    }

    // file or data transfers handled elsewhere if used

    // reachability changed
    public func session(_ session: WCSession, reachabilityDidChange isReachable: Bool) {
        Task { @MainActor in
            self.isReachable = isReachable
        }
        if isReachable {
            Task { await processQueueIfNeeded() }
        }
    }

    // MARK: - Queue + backend forwarding

    private func enqueuePacket(_ packet: [String: Any]) {
        // minimal validation
        var p = packet
        // add local metadata useful for merging
        p["_receivedAt"] = ISO8601DateFormatter().string(from: Date())
        p["_device"] = "iphone:\(UIDevice.current.identifierForVendor?.uuidString.prefix(6) ?? "local")"
        pendingPackets.append(p)
        Task { await processQueueIfNeeded() }
    }

    private func persistPendingPackets() {
        // basic local persistence for safety (optional)
        do {
            let data = try JSONSerialization.data(withJSONObject: pendingPackets, options: [])
            UserDefaults.standard.set(data, forKey: "iPhonePendingPackets")
        } catch {
            // ignore persistence errors
        }
    }

    private func restorePendingPackets() {
        guard let data = UserDefaults.standard.data(forKey: "iPhonePendingPackets") else { return }
        do {
            if let arr = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                pendingPackets = arr + pendingPackets
                UserDefaults.standard.removeObject(forKey: "iPhonePendingPackets")
            }
        } catch {
            // ignore
        }
    }

    private func processQueueIfNeeded() async {
        if isProcessingQueue { return }
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        // try restoring persisted queue first
        restorePendingPackets()

        while !pendingPackets.isEmpty {
            if !(session?.isReachable ?? false) {
                // if watch is offline, still try to forward to backend (phone may have network)
                // but if phone has no network, persist queue and stop
            }
            guard let packet = pendingPackets.first else {
                // Array became empty between check and access (race condition)
                break
            }
            do {
                let success = try await forwardToBackend(packet: packet)
                if success && !pendingPackets.isEmpty {
                    // remove first entry (safe because we checked isEmpty)
                    pendingPackets.removeFirst()
                } else {
                    // backend refused — break and persist
                    persistPendingPackets()
                    break
                }
            } catch {
                // network error — persist and break
                persistPendingPackets()
                break
            }
        }
    }

    private func forwardToBackend(packet: [String: Any]) async throws -> Bool {
        guard let url = URL(string: ingestURLString) else {
            print("Invalid ingest URL")
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try JSONSerialization.data(withJSONObject: packet, options: [])
        // Using async/await URLSession
        let (_, response) = try await URLSession.shared.upload(for: request, from: body)
        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            // optionally parse response
            return true
        } else {
            print("Backend error when forwarding packet:", (response as? HTTPURLResponse)?.statusCode ?? "unknown")
            // if 4xx, probably malformed -> drop or log; here treat as failure
            return false
        }
    }
}


