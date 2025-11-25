import Foundation
import Combine

final class TemplateStore: ObservableObject {
    @Published var templates: [TemplateModel] = []

    private let filename = "templates.json"

    // Combine cancellable for debounced saves
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 1) Load asynchronously so init never blocks the main thread.
        FileManager.loadAsync([TemplateModel].self, from: filename) { [weak self] loaded in
            guard let self = self else { return }
            if let l = loaded {
                self.templates = l
            } else {
                self.templates = []
            }
        }

        // 2) Debounce rapid changes and save on the main queue after 300ms of silence.
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
}
