// RoutineScheduleManager.swift
// Centralized manager for weekly workout routine scheduling

import Foundation
import Combine

/// Represents days of the week for scheduling
enum Weekday: Int, CaseIterable, Codable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var id: Int { rawValue }
    
    /// Full name (e.g., "Monday")
    var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
    
    /// Short name (e.g., "Mon")
    var shortName: String {
        String(fullName.prefix(3))
    }
    
    /// Get weekday from a Date
    static func from(date: Date) -> Weekday {
        let weekdayIndex = Calendar.current.component(.weekday, from: date)
        return Weekday(rawValue: weekdayIndex) ?? .sunday
    }
    
    /// Today's weekday
    static var today: Weekday {
        from(date: Date())
    }
}

/// Manages the weekly workout schedule - single source of truth
@MainActor
final class RoutineScheduleManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = RoutineScheduleManager()
    
    // MARK: - Published Properties
    
    /// Weekly schedule: Weekday → Template UUID (nil means rest day)
    @Published private(set) var weeklySchedule: [Weekday: UUID] = [:]
    
    // MARK: - Private Properties
    
    private let storageKey = "routine_schedule_v2"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    private init() {
        load()
        migrateFromOldSystems()
    }
    
    // MARK: - Public API
    
    /// Get today's scheduled template
    func todaysTemplate(from templates: [TemplateModel]) -> TemplateModel? {
        templateFor(weekday: .today, from: templates)
    }
    
    /// Get the template for a specific weekday
    func templateFor(weekday: Weekday, from templates: [TemplateModel]) -> TemplateModel? {
        guard let templateId = weeklySchedule[weekday] else { return nil }
        return templates.first(where: { $0.id == templateId })
    }
    
    /// Get the template ID for a specific weekday (nil = rest day)
    func templateId(for weekday: Weekday) -> UUID? {
        weeklySchedule[weekday]
    }
    
    /// Set the template for a weekday (pass nil for rest day)
    func setTemplate(for weekday: Weekday, templateId: UUID?) {
        if let id = templateId {
            weeklySchedule[weekday] = id
        } else {
            weeklySchedule.removeValue(forKey: weekday)
        }
        save()
    }
    
    /// Check if a weekday is a rest day
    func isRestDay(_ weekday: Weekday) -> Bool {
        weeklySchedule[weekday] == nil
    }
    
    /// Check if today is a rest day
    var isTodayRestDay: Bool {
        isRestDay(.today)
    }
    
    /// Get the template name for a weekday, or "Rest" if none
    func templateName(for weekday: Weekday, from templates: [TemplateModel]) -> String {
        if let template = templateFor(weekday: weekday, from: templates) {
            return template.name
        }
        return "Rest"
    }
    
    /// Get today's template name
    func todaysTemplateName(from templates: [TemplateModel]) -> String {
        templateName(for: .today, from: templates)
    }
    
    // MARK: - Persistence
    
    private func save() {
        // Convert [Weekday: UUID] to [Int: String] for JSON encoding
        let encodable = weeklySchedule.reduce(into: [Int: String]()) { result, pair in
            result[pair.key.rawValue] = pair.value.uuidString
        }
        
        if let data = try? encoder.encode(encodable) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? decoder.decode([Int: String].self, from: data) else {
            return
        }
        
        // Convert [Int: String] back to [Weekday: UUID]
        weeklySchedule = decoded.reduce(into: [Weekday: UUID]()) { result, pair in
            if let weekday = Weekday(rawValue: pair.key),
               let uuid = UUID(uuidString: pair.value) {
                result[weekday] = uuid
            }
        }
    }
    
    // MARK: - Migration from Old Systems
    
    private func migrateFromOldSystems() {
        // Only migrate if we don't already have data
        guard weeklySchedule.isEmpty else { return }
        
        var migrated = false
        
        // Try to migrate from WeeklyRoutinePlannerView's @AppStorage("weeklyAssignments")
        if let data = UserDefaults.standard.data(forKey: "weeklyAssignments"),
           let oldAssignments = try? JSONDecoder().decode([String: UUID].self, from: data) {
            
            // Map day names to weekdays
            let dayMapping: [String: Weekday] = [
                "Monday": .monday, "Tuesday": .tuesday, "Wednesday": .wednesday,
                "Thursday": .thursday, "Friday": .friday, "Saturday": .saturday, "Sunday": .sunday
            ]
            
            // Get rest day UUID to exclude
            let restDayUUIDString = UserDefaults.standard.string(forKey: "restDayUUID") ?? ""
            let restDayUUID = UUID(uuidString: restDayUUIDString)
            
            for (dayName, templateId) in oldAssignments {
                if let weekday = dayMapping[dayName], templateId != restDayUUID {
                    weeklySchedule[weekday] = templateId
                }
            }
            
            migrated = true
        }
        
        // If no data from WeeklyRoutinePlannerView, try RoutineStore
        if !migrated {
            if let _ = UserDefaults.standard.dictionary(forKey: "routine_weekly_v1") as? [String: String] {
                // This system stored day -> template name, not IDs
                // We'll skip this migration since we don't have template IDs
                // Users will need to re-assign their schedule
            }
        }
        
        // Save migrated data
        if !weeklySchedule.isEmpty {
            save()
            
            // Clean up old storage keys
            UserDefaults.standard.removeObject(forKey: "weeklyAssignments")
            UserDefaults.standard.removeObject(forKey: "restDayUUID")
            UserDefaults.standard.removeObject(forKey: "routine_weekly_v1")
            UserDefaults.standard.removeObject(forKey: "routine_overrides_v1")
        }
    }
    
    // MARK: - Utility
    
    /// Create a WorkoutRecord from a template
    static func createWorkoutRecord(from template: TemplateModel) -> WorkoutRecord {
        let exercises: [WorkoutExerciseRecord] = template.exercises.map { exerciseModel in
            let sets: [WorkoutSetRecord] = exerciseModel.sets.map { rep in
                WorkoutSetRecord(
                    reps: 0,
                    weight: 0,
                    note: rep.note
                )
            }
            return WorkoutExerciseRecord(
                name: exerciseModel.name,
                sets: sets.isEmpty ? [WorkoutSetRecord(reps: 0, weight: 0)] : sets,
                notes: nil,
                muscleGroups: exerciseModel.muscleGroups
            )
        }
        
        return WorkoutRecord(
            templateName: template.name,
            exercises: exercises
        )
    }
}
