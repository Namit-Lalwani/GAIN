import Foundation
import Combine

final class TemplateStore: ObservableObject {
    @Published var templates: [TemplateModel] = []

    private let filename = "templates.json"

    // Combine cancellable for debounced saves
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 1) Determine if a templates file already exists so we don't overwrite
        // user-created routines on decode errors.
        let url = FileManager.fileURL(filename)
        let hasExistingFile = FileManager.default.fileExists(atPath: url.path)

        // 2) Load synchronously at startup so templates are ready before first use
        // (e.g., when starting today's routine). The file is small, so this is safe.
        if let loaded: [TemplateModel] = FileManager.load([TemplateModel].self, from: filename) {
            self.templates = loaded
        } else {
            self.templates = []
            // Only seed defaults on true first run (no existing file).
            if !hasExistingFile {
                self.seedDefaultRoutinesIfNeeded()
            }
        }

        // 3) Debounce rapid changes and save on the main queue after 300ms of silence.
        // This prevents many tiny saves while user is typing or tapping steppers.
        $templates
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newTemplates in
                guard let self = self else { return }
                // Save using FileManager.save (already async)
                FileManager.save(newTemplates, to: self.filename)
            }
            .store(in: &cancellables)
    }

    // MARK: - CRUD

    func add(_ t: TemplateModel) {
        templates.append(t)
    }

    func update(_ t: TemplateModel) {
        guard let i = templates.firstIndex(where: { $0.id == t.id }) else { return }
        templates[i] = t
    }

    func delete(id: UUID) {
        templates.removeAll { $0.id == id }
    }

    // For manual saves (shouldn't be necessary because of debounced auto-save)
    func forceSaveNow() {
        FileManager.save(templates, to: filename)
    }

    // MARK: - Default Routines

    private func seedDefaultRoutinesIfNeeded() {
        guard templates.isEmpty else { return }

        let pushExercises = [
            "Machine Fly ( Pec Deck)",
            "Tricep Pushdown",
            "Bench Press",
            "Inc Dumbell Press",
            "Cable Overhead Triceps Extension",
            "Decline Bench Press",
            "One arm Cable Cross Over"
        ].map { Exercise(name: $0, sets: []) }

        let pullExercises = [
            "Incline Dumbell Curl",
            "One Arm inclined cable Lat Pulldown",
            "Pull-Up",
            "Barbell Preacher Curls",
            "Chest Supported Rows",
            "Seated Cable Rows",
            "One Arm Dumbbell Row",
            "Reverse Pec Deck",
            "Lat Pulldown"
        ].map { Exercise(name: $0, sets: []) }

        let lowerBodyExercises = [
            "Hack Squat",
            "Single Leg Extension",
            "Abb wheel",
            "Russian Twists",
            "Dragonfly raise",
            "Standing Calf Raise",
            "Leg Press",
            "Seated Calf Raises",
            "Barbell Squat",
            "Bulgarian Split Squat",
            "Leg Curl"
        ].map { Exercise(name: $0, sets: []) }
        
        let defaults: [TemplateModel] = [
            TemplateModel(name: "Push", exercises: pushExercises),
            TemplateModel(name: "Pull", exercises: pullExercises),
            TemplateModel(name: "Lower Body", exercises: lowerBodyExercises),
            TemplateModel(name: "Push", exercises: pushExercises),
            TemplateModel(name: "Pull", exercises: pullExercises),
            TemplateModel(name: "Lower Body", exercises: lowerBodyExercises)
        ]

        templates = defaults
        forceSaveNow()
    }
}
