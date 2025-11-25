import Foundation
import Combine

// Simple weekly routine + calendar override models
// Weekdays use short names "Mon","Tue","Wed","Thu","Fri","Sat","Sun"

final class RoutineStore: ObservableObject {
    @Published var weekly: [String: String] // day -> template name (or "Rest")
    @Published var overrides: [String: String] // "yyyy-MM-dd" -> template name

    private let weeklyKey = "routine_weekly_v1"
    private let overridesKey = "routine_overrides_v1"

    init() {
        self.weekly = [
            "Mon": "Push",
            "Tue": "Pull",
            "Wed": "Legs",
            "Thu": "Rest",
            "Fri": "Upper",
            "Sat": "Accessory",
            "Sun": "Rest"
        ]
        self.overrides = [:]
        load()
    }

    // MARK: - Helpers
    func templateFor(date: Date) -> String {
        let key = RoutineStore.dateKey(from: date)
        if let o = overrides[key] { return o }
        let weekday = RoutineStore.shortWeekday(from: date)
        return weekly[weekday] ?? "Custom"
    }

    func setOverride(for date: Date, templateName: String) {
        overrides[Self.dateKey(from: date)] = templateName
        save()
    }

    func removeOverride(for date: Date) {
        overrides.removeValue(forKey: Self.dateKey(from: date))
        save()
    }

    func setWeekly(dayShortName: String, templateName: String) {
        weekly[dayShortName] = templateName
        save()
    }

    // MARK: - Persistence (simple)
    private func save() {
        UserDefaults.standard.set(weekly, forKey: weeklyKey)
        UserDefaults.standard.set(overrides, forKey: overridesKey)
    }

    private func load() {
        if let w = UserDefaults.standard.dictionary(forKey: weeklyKey) as? [String: String] {
            self.weekly = w
        }
        if let o = UserDefaults.standard.dictionary(forKey: overridesKey) as? [String: String] {
            self.overrides = o
        }
    }

    static func dateKey(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func shortWeekday(from date: Date) -> String {
        let cal = Calendar.current
        let idx = cal.component(.weekday, from: date) // 1 = Sun
        // Map to Mon..Sun
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return names[(idx - 1) % 7]
    }
}
