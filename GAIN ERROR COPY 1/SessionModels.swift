import Foundation

// MARK: - Session Status
public enum SessionStatus: String, Codable {
    case running
    case paused
    case ended
}

// MARK: - Metric
public struct Metric: Identifiable, Codable {
    public let id: UUID
    public var timestamp: Date
    public var heartRate: Double?
    public var power: Double?
    public var cadence: Double?
    public var secondsElapsed: TimeInterval?
    public var customData: [String: AnyCodable]?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        heartRate: Double? = nil,
        power: Double? = nil,
        cadence: Double? = nil,
        secondsElapsed: TimeInterval? = nil,
        customData: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.power = power
        self.cadence = cadence
        self.secondsElapsed = secondsElapsed
        self.customData = customData
    }
}

// MARK: - Workout Session
public struct WorkoutSession: Identifiable, Codable {
    public let id: UUID
    public var workoutId: UUID? // Reference to workout template/record
    public var startedAt: Date
    public var endedAt: Date?
    public var status: SessionStatus
    public var metrics: [Metric]
    public var finalMetrics: [String: AnyCodable]?
    public var deviceId: String // For conflict resolution
    public var revision: Int // For conflict resolution
    
    public init(
        id: UUID = UUID(),
        workoutId: UUID? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: SessionStatus = .running,
        metrics: [Metric] = [],
        finalMetrics: [String: AnyCodable]? = nil,
        deviceId: String = WorkoutSession.defaultDeviceId,
        revision: Int = 1
    ) {
        self.id = id
        self.workoutId = workoutId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status
        self.metrics = metrics
        self.finalMetrics = finalMetrics
        self.deviceId = deviceId
        self.revision = revision
    }
    
    public var duration: TimeInterval {
        if let endedAt = endedAt {
            return endedAt.timeIntervalSince(startedAt)
        }
        return Date().timeIntervalSince(startedAt)
    }
    
    public static var defaultDeviceId: String {
        #if canImport(UIKit)
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        #else
        return "unknown"
        #endif
    }
}

// MARK: - AnyCodable (for flexible JSON encoding)
public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif

