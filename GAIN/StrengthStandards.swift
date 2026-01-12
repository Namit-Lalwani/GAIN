import Foundation

/// Defines a normalized 8-tier strength system based on anchor exercises.
struct StrengthStandards {
    enum Tier: Int, CaseIterable, Comparable {
        case tier1 = 1
        case tier2
        case tier3
        case tier4
        case tier5
        case tier6
        case tier7
        case tier8
        
        var label: String {
            switch self {
            case .tier1: return "Novice"
            case .tier2: return "Bronze"
            case .tier3: return "Silver"
            case .tier4: return "Gold"
            case .tier5: return "Platinum"
            case .tier6: return "Diamond"
            case .tier7: return "Beast"
            case .tier8: return "Elite"
            }
        }
        
        /// 0–100 score for charts/badges.
        var score0to100: Double {
            Double(rawValue - 1) / 7.0 * 100.0
        }
        
        static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Thresholds for a single anchor lift (all values in kilograms).
    struct Thresholds {
        let eMax: Double
        let dRange: ClosedRange<Double>
        let cRange: ClosedRange<Double>
        let bRange: ClosedRange<Double>
        let aMin: Double
        
        fileprivate var eMid: Double { eMax / 2.0 }
        fileprivate var dMid: Double { (dRange.lowerBound + dRange.upperBound) / 2.0 }
        fileprivate var cMid: Double { (cRange.lowerBound + cRange.upperBound) / 2.0 }
    }
    
    /// Lookup table for all anchor exercises (including common aliases).
    static let thresholdsByExerciseName: [String: Thresholds] = {
        let benchPress = Thresholds(eMax: 60, dRange: 60...80, cRange: 80...100, bRange: 100...120, aMin: 120)
        let inclineBench = Thresholds(eMax: 50, dRange: 50...70, cRange: 70...90, bRange: 90...105, aMin: 105)
        let dumbbellBench = Thresholds(eMax: 40, dRange: 40...60, cRange: 60...80, bRange: 80...100, aMin: 100)
        let deadlift = Thresholds(eMax: 100, dRange: 100...140, cRange: 140...180, bRange: 180...220, aMin: 220)
        let row = Thresholds(eMax: 60, dRange: 60...80, cRange: 80...100, bRange: 100...120, aMin: 120)
        let pullUp = Thresholds(eMax: 0, dRange: 0...15, cRange: 15...30, bRange: 30...45, aMin: 45)
        let squat = Thresholds(eMax: 100, dRange: 100...140, cRange: 140...180, bRange: 180...220, aMin: 220)
        let frontSquat = Thresholds(eMax: 80, dRange: 80...110, cRange: 110...140, bRange: 140...170, aMin: 170)
        let hackSquat = Thresholds(eMax: 120, dRange: 120...180, cRange: 180...240, bRange: 240...300, aMin: 300)
        let rdl = Thresholds(eMax: 80, dRange: 80...110, cRange: 110...140, bRange: 140...170, aMin: 170)
        let legCurl = Thresholds(eMax: 40, dRange: 40...60, cRange: 60...80, bRange: 80...100, aMin: 100)
        let hipThrust = Thresholds(eMax: 120, dRange: 120...180, cRange: 180...240, bRange: 240...300, aMin: 300)
        let ohp = Thresholds(eMax: 40, dRange: 40...55, cRange: 55...70, bRange: 70...85, aMin: 85)
        let dbShoulder = Thresholds(eMax: 30, dRange: 30...45, cRange: 45...60, bRange: 60...75, aMin: 75)
        let lateralRaise = Thresholds(eMax: 6, dRange: 6...10, cRange: 10...14, bRange: 14...18, aMin: 18)
        let barbellCurl = Thresholds(eMax: 30, dRange: 30...40, cRange: 40...50, bRange: 50...60, aMin: 60)
        let dbCurl = Thresholds(eMax: 12, dRange: 12...18, cRange: 18...24, bRange: 24...30, aMin: 30)
        let preacherCurl = Thresholds(eMax: 25, dRange: 25...35, cRange: 35...45, bRange: 45...55, aMin: 55)
        let closeGripBench = Thresholds(eMax: 55, dRange: 55...75, cRange: 75...95, bRange: 95...115, aMin: 115)
        let dip = Thresholds(eMax: 0, dRange: 0...15, cRange: 15...30, bRange: 30...45, aMin: 45)
        let overheadExtension = Thresholds(eMax: 25, dRange: 25...35, cRange: 35...45, bRange: 45...55, aMin: 55)
        let standingCalf = Thresholds(eMax: 60, dRange: 60...90, cRange: 90...120, bRange: 120...150, aMin: 150)
        let seatedCalf = Thresholds(eMax: 50, dRange: 50...80, cRange: 80...110, bRange: 110...140, aMin: 140)
        let plank = Thresholds(eMax: 0, dRange: 0...0, cRange: 10...20, bRange: 20...30, aMin: 30)

        var dict: [String: Thresholds] = [:]

        func add(_ names: [String], thresholds: Thresholds) {
            for name in names {
                dict[name] = thresholds
            }
        }

        // Chest
        add(["Bench Press", "Barbell Bench Press", "Flat Bench Press"], thresholds: benchPress)
        add(["Incline Bench Press", "Barbell Incline Bench Press"], thresholds: inclineBench)
        add(["Dumbbell Bench Press", "DB Bench Press"], thresholds: dumbbellBench)

        // Back
        add(["Deadlift", "Barbell Deadlift", "Conventional Deadlift"], thresholds: deadlift)
        add(["Barbell Row", "Bent Over Row"], thresholds: row)
        add(["Pull-Up", "Weighted Pull-Up", "Chin-Up", "Weighted Chin-Up"], thresholds: pullUp)

        // Quads / Glutes
        add(["Barbell Squat", "Back Squat", "Squat"], thresholds: squat)
        add(["Front Squat"], thresholds: frontSquat)
        add(["Hack Squat"], thresholds: hackSquat)
        add(["Hip Thrust", "Barbell Hip Thrust"], thresholds: hipThrust)

        // Hamstrings
        add(["Romanian Deadlift", "RDL", "Romanian Dead Lift"], thresholds: rdl)
        add(["Leg Curl", "Lying Leg Curl"], thresholds: legCurl)
        add(["Seated Leg Curl"], thresholds: legCurl)

        // Shoulders
        add(["Overhead Press", "Standing Overhead Press", "Military Press"], thresholds: ohp)
        add(["Dumbbell Shoulder Press", "Seated Dumbbell Shoulder Press"], thresholds: dbShoulder)
        add(["Lateral Raise", "Dumbbell Lateral Raise"], thresholds: lateralRaise)

        // Biceps
        add(["Barbell Curl"], thresholds: barbellCurl)
        add(["Dumbbell Curl", "Alternating Dumbbell Curl"], thresholds: dbCurl)
        add(["Preacher Curl", "Barbell Preacher Curl"], thresholds: preacherCurl)

        // Triceps
        add(["Close-Grip Bench Press", "Close Grip Bench"], thresholds: closeGripBench)
        add(["Tricep Dips", "Weighted Dip", "Dip"], thresholds: dip)
        add(["Overhead Tricep Extension", "EZ Bar Overhead Extension"], thresholds: overheadExtension)

        // Calves
        add(["Standing Calf Raise"], thresholds: standingCalf)
        add(["Seated Calf Raise"], thresholds: seatedCalf)

        // Core
        add(["Plank", "Weighted Plank"], thresholds: plank)

        return dict
    }()
}

extension StrengthStandards {
    /// Returns the 8-tier classification for a given 1RM and anchor exercise.
    static func tier(forOneRM oneRM: Double, exerciseName: String) -> Tier? {
        guard let thresholds = thresholdsByExerciseName[exerciseName] else { return nil }
        return tier(forOneRM: oneRM, thresholds: thresholds)
    }
    
    static func tier(forOneRM oneRM: Double, thresholds: Thresholds) -> Tier {
        guard oneRM > 0 else { return .tier1 }
        
        if oneRM < thresholds.eMid {
            return .tier1
        } else if oneRM < thresholds.eMax {
            return .tier2
        } else if oneRM < thresholds.dMid {
            return .tier3
        } else if oneRM < thresholds.dRange.upperBound {
            return .tier4
        } else if oneRM < thresholds.cMid {
            return .tier5
        } else if oneRM < thresholds.cRange.upperBound {
            return .tier6
        } else if oneRM < thresholds.bRange.upperBound {
            return .tier7
        } else if oneRM >= thresholds.aMin {
            return .tier8
        }
        
        return .tier7
    }
    
    /// Maps a normalized 0–1 score into the 8-tier system.
    static func tier(forRelativeScore normalizedScore: Double) -> Tier {
        let clamped = max(0, min(1, normalizedScore))
        let scaled = clamped * Double(Tier.allCases.count - 1) // 0...7
        let rawValue = Int(scaled.rounded(.down)) + 1
        return Tier(rawValue: rawValue) ?? .tier1
    }
}
