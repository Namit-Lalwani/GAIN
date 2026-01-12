import Foundation
import Combine

struct BodyFrameSettings: Codable {
    var shoulderWidth: Double
    var waistWidth: Double
    var hipWidth: Double
    var torsoLength: Double
    var legLength: Double
    var limbThickness: Double
}

struct MuscleGeneticSettings: Codable {
    var baselineSize: Double   // 0.0–1.0 visual base size
    var growthRateBias: Double // ~0.5–1.5 relative growth speed
}

struct BodyProfile: Codable {
    var heightCm: Double
    var weightKg: Double
    var frame: BodyFrameSettings
    /// Genetics keyed by high-level muscle group, e.g. "Chest", "Back", "Quads"
    var muscleGenetics: [String: MuscleGeneticSettings]
}

final class BodyProfileStore: ObservableObject {
    @Published var profile: BodyProfile {
        didSet {
            save()
        }
    }
    
    private let filename = "body_profile.json"
    
    init() {
        if let loaded: BodyProfile = FileManager.load(BodyProfile.self, from: filename) {
            self.profile = loaded
        } else {
            self.profile = BodyProfileStore.defaultProfile()
            FileManager.save(self.profile, to: filename)
        }
    }
    
    func save() {
        FileManager.save(profile, to: filename)
    }
    
    private static func defaultProfile() -> BodyProfile {
        let frame = BodyFrameSettings(
            shoulderWidth: 0.6,
            waistWidth: 0.4,
            hipWidth: 0.5,
            torsoLength: 0.5,
            legLength: 0.5,
            limbThickness: 0.5
        )
        let defaultGenetics: [String: MuscleGeneticSettings] = [
            "Chest": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Back": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Quads": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Hamstrings": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Glutes": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Deltoids": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Biceps": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Triceps": .init(baselineSize: 0.5, growthRateBias: 1.0),
            "Calves": .init(baselineSize: 0.5, growthRateBias: 1.0)
        ]
        return BodyProfile(
            heightCm: 175,
            weightKg: 75,
            frame: frame,
            muscleGenetics: defaultGenetics
        )
    }
}
