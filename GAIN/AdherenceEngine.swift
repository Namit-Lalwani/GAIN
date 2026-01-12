// AdherenceEngine.swift
import Foundation

public struct DailyAdherence: Identifiable {
    public let id = UUID()
    public let date: Date        // midnight-normalized date
    public let hasWorkout: Bool
}

public struct AdherenceSummary {
    public let totalDays: Int
    public let daysWithWorkout: Int
    public let currentStreak: Int
    public let longestStreak: Int
    public let consistencyScore: Double   // 0–100
}

public struct WeeklyAdherenceSummary: Identifiable {
    public let id = UUID()
    public let weekStart: Date        // start-of-week (ISO week)
    public let workoutsDone: Int      // number of days with ≥1 workout
    public let totalSessions: Int     // total workouts (could be > workoutsDone)
    public let targetWorkouts: Int    // planned workouts per week
    public let metTarget: Bool        // true if workoutsDone >= targetWorkouts
}

public enum AdherenceEngine {
    
    // MARK: - Helpers
    
    /// Normalize a date to midnight in the current calendar/timezone.
    private static func dayStart(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    /// Returns a map of `dayStart -> count of workouts` between the two dates (inclusive).
    private static func workoutsByDay(
        workouts: [WorkoutRecord],
        from start: Date,
        to end: Date
    ) -> [Date: Int] {
        var map: [Date: Int] = [:]
        for w in workouts {
            let d = dayStart(for: w.start)
            if d >= start && d <= end {
                map[d, default: 0] += 1
            }
        }
        return map
    }
    
    // MARK: - Daily adherence & streaks
    
    /// Build a daily adherence timeline for the last `days` days (including today).
    public static func dailyAdherence(
        workouts: [WorkoutRecord],
        days: Int = 30
    ) -> [DailyAdherence] {
        guard days > 0 else { return [] }
        
        let calendar = Calendar.current
        let today = dayStart(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }
        
        let map = workoutsByDay(workouts: workouts, from: start, to: today)
        
        var result: [DailyAdherence] = []
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let hasWorkout = (map[date] ?? 0) > 0
            result.append(DailyAdherence(date: date, hasWorkout: hasWorkout))
        }
        return result
    }
    
    /// Compute adherence summary (streaks & consistency) for last `days` days.
    public static func summary(
        workouts: [WorkoutRecord],
        days: Int = 30
    ) -> AdherenceSummary {
        let daily = dailyAdherence(workouts: workouts, days: days)
        guard !daily.isEmpty else {
            return AdherenceSummary(
                totalDays: 0,
                daysWithWorkout: 0,
                currentStreak: 0,
                longestStreak: 0,
                consistencyScore: 0
            )
        }
        
        let daysWithWorkout = daily.filter { $0.hasWorkout }.count
        
        // Compute longest streak over the window
        var longest = 0
        var currentRun = 0
        
        for day in daily {
            if day.hasWorkout {
                currentRun += 1
                longest = max(longest, currentRun)
            } else {
                currentRun = 0
            }
        }
        
        // Current streak = run from the end backwards
        var currentStreak = 0
        for day in daily.reversed() {
            if day.hasWorkout {
                currentStreak += 1
            } else {
                break
            }
        }
        
        // Consistency: percentage of days with a workout, scaled 0–100
        let consistency = Double(daysWithWorkout) / Double(daily.count) * 100.0
        
        return AdherenceSummary(
            totalDays: daily.count,
            daysWithWorkout: daysWithWorkout,
            currentStreak: currentStreak,
            longestStreak: longest,
            consistencyScore: consistency
        )
    }
    
    // MARK: - Weekly targets (planned vs done)
    
    /// Compute weekly adherence compared to a target number of workout days per week.
    /// - Parameters:
    ///   - workouts: All workout records.
    ///   - weeksBack: How many weeks back to include (including this week).
    ///   - targetPerWeek: Planned workout days per week (e.g. 3 or 4).
    public static func weeklySummary(
        workouts: [WorkoutRecord],
        weeksBack: Int = 8,
        targetPerWeek: Int = 3
    ) -> [WeeklyAdherenceSummary] {
        guard weeksBack > 0 else { return [] }
        guard !workouts.isEmpty else { return [] }
        
        let calendar = Calendar(identifier: .iso8601)
        
        // Map workouts to weekStart -> [WorkoutRecord]
        var weeks: [Date: [WorkoutRecord]] = [:]
        for w in workouts {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: w.start)
            guard let weekStart = calendar.date(from: comps) else { continue }
            weeks[weekStart, default: []].append(w)
        }
        
        // Determine current ISO week start (this week)
        let today = Date()
        let todayComps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        let currentWeekStart = calendar.date(from: todayComps) ?? today
        
        var result: [WeeklyAdherenceSummary] = []
        
        // Oldest → newest
        for offset in stride(from: weeksBack - 1, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart) else {
                continue
            }
            let ws = weeks[weekStart] ?? []
            
            // Unique days with at least one workout
            let dayStarts = Set(ws.map { calendar.startOfDay(for: $0.start) })
            
            let workoutsDone = dayStarts.count
            let totalSessions = ws.count
            let metTarget = workoutsDone >= targetPerWeek
            
            result.append(
                WeeklyAdherenceSummary(
                    weekStart: weekStart,
                    workoutsDone: workoutsDone,
                    totalSessions: totalSessions,
                    targetWorkouts: targetPerWeek,
                    metTarget: metTarget
                )
            )
        }
        
        return result
    }
}
