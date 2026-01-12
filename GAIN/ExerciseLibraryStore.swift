import Foundation
import Combine

struct ExerciseDefinition: Identifiable, Decodable {
    let id: UUID
    let name: String
    let primaryMuscles: [String]?
    let secondaryMuscles: [String]?
    let equipment: [String]?
    let category: String?
    let muscleHeadTargeting: [String: MuscleHeadTargeting]?

    private enum CodingKeys: String, CodingKey {
        case name
        case primaryMuscles
        case secondaryMuscles
        case equipment
        case category
        case muscleHeadTargeting
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.primaryMuscles = try container.decodeIfPresent([String].self, forKey: .primaryMuscles)
        self.secondaryMuscles = try container.decodeIfPresent([String].self, forKey: .secondaryMuscles)
        self.equipment = try container.decodeIfPresent([String].self, forKey: .equipment)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.muscleHeadTargeting = try container.decodeIfPresent([String: MuscleHeadTargeting].self, forKey: .muscleHeadTargeting)
        self.id = UUID()
    }
}

struct MuscleHeadTargeting: Decodable {
    let heads: [String]
    let targetingDistribution: [String: String]
    let description: String?
}

final class ExerciseLibraryStore: ObservableObject {
    @Published private(set) var exercises: [ExerciseDefinition] = []

    init() {
        loadFromBundle()
    }

    private func loadFromBundle() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            print("❌ ERROR: exercises.json not found in bundle!")
            print("💡 Make sure exercises.json is added to your Xcode target")
            loadFallbackExercises()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([ExerciseDefinition].self, from: data)
            DispatchQueue.main.async {
                self.exercises = decoded
                print("✅ Successfully loaded \(decoded.count) exercises from JSON")
            }
        } catch {
            print("❌ ERROR loading exercises.json: \(error.localizedDescription)")
            loadFallbackExercises()
        }
    }
    
    private func loadFallbackExercises() {
        // Fallback exercises if JSON fails to load
        let fallback = [
            ("Bench Press", ["Chest"], ["Triceps", "Shoulders"]),
            ("Squat", ["Quadriceps", "Glutes"], ["Hamstrings", "Core"]),
            ("Deadlift", ["Back", "Hamstrings", "Glutes"], ["Core", "Traps"]),
            ("Pull-Up", ["Lats", "Back"], ["Biceps", "Forearms"]),
            ("Overhead Press", ["Shoulders"], ["Triceps", "Upper Chest"]),
            ("Barbell Row", ["Back", "Lats"], ["Biceps", "Rear Delts"]),
            ("Dumbbell Curl", ["Biceps"], ["Forearms"]),
            ("Tricep Pushdown", ["Triceps"], []),
            ("Leg Press", ["Quadriceps", "Glutes"], ["Hamstrings"]),
            ("Lat Pulldown", ["Lats"], ["Biceps", "Rear Delts"])
        ].map { (name, primary, secondary) in
            // Create a simple JSON and decode it
            let json = """
            {
                "name": "\(name)",
                "primaryMuscles": [\(primary.map { "\"\($0)\"" }.joined(separator: ","))],
                "secondaryMuscles": [\(secondary.map { "\"\($0)\"" }.joined(separator: ","))],
                "equipment": ["Barbell"],
                "category": "Strength"
            }
            """
            return try! JSONDecoder().decode(ExerciseDefinition.self, from: json.data(using: .utf8)!)
        }
        
        DispatchQueue.main.async {
            self.exercises = fallback
            print("⚠️ Using fallback exercises (\(fallback.count) exercises)")
        }
    }

    func filtered(by searchText: String) -> [ExerciseDefinition] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
