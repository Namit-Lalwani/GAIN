import Foundation

// Reuse existing RepSet and Exercise models for template planning
// Template stores planned sets (reps/weight) for each exercise

struct TemplateModel: Identifiable, Codable {
    let id: UUID
    var name: String
    var exercises: [Exercise] // Exercise contains planned RepSet items

    init(id: UUID = UUID(), name: String = "New Routine", exercises: [Exercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
