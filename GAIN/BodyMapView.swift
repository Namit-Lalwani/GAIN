import SwiftUI
import Charts

struct BodyMapView: View {
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var exerciseLibraryStore: ExerciseLibraryStore
    @EnvironmentObject private var bodyProfileStore: BodyProfileStore
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case month = "30 days"
        case threeMonths = "90 days"
        case year = "1 year"
        case all = "All time"
        
        var id: String { rawValue }
    }
    
    // MARK: - Tier helpers
    
    /// Maps a 0–100 score into our 8-tier UI system with distinct colors.
    private func tier(for score: Double) -> (label: String, color: Color) {
        let clamped = max(0, min(100, score))
        let index = min(7, max(0, Int(clamped / 12.5))) // 0...7
        switch index {
        case 0:
            // Novice – neutral gray
            return ("Novice", Color.black.opacity(1))
        case 1:
            // Bronze – warm brown
            return ("Bronze", Color.brown.opacity(0.85))
        case 2:
            // Silver – light cool gray
            return ("Silver", Color.gray.opacity(0.25))
        case 3:
            // Gold – saturated yellow
            return ("Gold", Color.yellow.opacity(0.9))
        case 4:
            // Platinum – bright cyan
            return ("Platinum", Color.cyan.opacity(0.9))
        case 5:
            // Diamond – deep blue
            return ("Diamond", Color.blue.opacity(0.85))
        case 6:
            // Beast – strong red
            return ("Beast", Color.red.opacity(0.9))
        default:
            // Elite – royal purple
            return ("Elite", Color.purple.opacity(0.85))
        }
    }
    
    private enum BodyRegionID: String, CaseIterable, Hashable {
        case chestUpper, chestMid, chestLower
        case deltsFront, deltsSide, deltsRear
        case armsBiceps, armsTriceps
        case backUpper, backMid, backLower
        case core
        case quadsFront, hamsBack
        case glutes
        case calves
    }
    
    @State private var selectedTimeframe: Timeframe = .threeMonths
    @State private var showGenetics: Bool = false
    @State private var showDebugHeatmap: Bool = false
    @State private var selectedGroupRanking: BodyStrengthRankingEngine.GroupRanking?
    
    /// Strength-focused per-head stats using estimated 1RM under the hood.
    private var filteredStats: [BodyMapEngine.MuscleHeadStats] {
        let (start, end) = dateRange(for: selectedTimeframe)
        return BodyMapEngine.computeMuscleHeadStrengthStats(
            workouts: workoutStore.records,
            exerciseLibrary: exerciseLibraryStore.exercises,
            startDate: start,
            endDate: end
        )
    }
    
    /// Anchor-based 8-tier strength rankings per muscle group plus per-head breakdowns.
    private var strengthRankings: [BodyStrengthRankingEngine.GroupRanking] {
        let (start, end) = dateRange(for: selectedTimeframe)
        return BodyStrengthRankingEngine.computeRankings(
            workouts: workoutStore.records,
            exerciseLibrary: exerciseLibraryStore.exercises,
            startDate: start,
            endDate: end
        )
    }

    private var strongestRegions: [BodyMapEngine.MuscleHeadStats] {
        Array(filteredStats.prefix(5))
    }
    
    private var weakestRegions: [BodyMapEngine.MuscleHeadStats] {
        Array(filteredStats.sorted { $0.relativeScore < $1.relativeScore }.prefix(5))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    timeframeCard
                    bodyMapCard
                    legendCard
                    highlightsCard
                    geneticsCard
                    debugCard
                }
                .padding()
            }
            .navigationTitle("Body Map")
            .background(Color(.systemGroupedBackground))
        }
        .sheet(item: $selectedGroupRanking) { group in
            NavigationView {
                MuscleGroupDetailView(group: group)
            }
        }
    }

    // MARK: - Subviews

    private var timeframeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeframe")
                .font(.headline)
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(Timeframe.allCases) { tf in
                    Text(tf.rawValue).tag(tf)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var bodyMapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Muscle strength rankings")
                    .font(.headline)
                Spacer()
            }
            if strengthRankings.isEmpty {
                Text("Not enough workout data yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(strengthRankings) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(group.displayName)
                                    .font(.subheadline).bold()
                                Spacer()
                                let score = group.tier.score0to100
                                let tierInfo = tier(for: score)
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(tierInfo.color)
                                        .frame(width: 14, height: 14)
                                    Text(tierInfo.label)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.0f", score))
                                        .font(.caption).bold()
                                }
                            }
                            if let best = group.bestAnchor {
                                Text("Best anchor: \(best.exerciseName) – \(String(format: "%.1f", best.bestOneRM)) kg")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            ForEach(group.headRankings) { head in
                                HStack {
                                    Text(head.headName)
                                        .font(.caption)
                                    Spacer()
                                    let headTierInfo = tier(for: head.score0to100)
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(headTierInfo.color)
                                            .frame(width: 10, height: 10)
                                        Text(headTierInfo.label)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(String(format: "%.0f", head.score0to100))
                                            .font(.caption2).bold()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            selectedGroupRanking = group
                        }
                        Divider()
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strength tiers")
                .font(.subheadline).bold()
            HStack(spacing: 12) {
                legendSwatchForTier(0)
                legendSwatchForTier(1)
                legendSwatchForTier(2)
                legendSwatchForTier(3)
            }
            HStack(spacing: 12) {
                legendSwatchForTier(4)
                legendSwatchForTier(5)
                legendSwatchForTier(6)
                legendSwatchForTier(7)
                Spacer()
            }
            Text("Eight tiers from beginner to elite, based on anchor lifts (bench, squat, deadlift, etc.) and training volume for each muscle group.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .font(.caption)
        }
    }
    
    private func legendSwatchForTier(_ index: Int) -> some View {
        let tierCount = Double(StrengthStandards.Tier.allCases.count)
        let step = 100.0 / tierCount
        let centerScore = (Double(index) + 0.5) * step
        let info = tier(for: centerScore)
        return legendSwatch(color: info.color, label: info.label)
    }

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Highlights")
                .font(.headline)
            if strongestRegions.isEmpty {
                Text("No regions scored yet")
                    .foregroundColor(.secondary)
            } else {
                if let top = strongestRegions.first {
                    HStack(spacing: 0) {
                        Text("Strongest region: \(top.group) – \(top.head) (")
                        Text(String(format: "%.0f", top.relativeScore)).bold()
                        Text(" strength score)")
                    }
                }
                if let weak = weakestRegions.first(where: { $0.relativeScore > 0 }) {
                    HStack(spacing: 0) {
                        Text("Weakest region: \(weak.group) – \(weak.head) (")
                        Text(String(format: "%.0f", weak.relativeScore)).bold()
                        Text(" strength score)")
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var geneticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Genetics & Frame")
                    .font(.headline)
                Spacer()
                Button(showGenetics ? "Hide" : "Adjust") {
                    withAnimation { showGenetics.toggle() }
                }
                .font(.subheadline)
            }
            if showGenetics {
                GeneticsControlsView(profile: $bodyProfileStore.profile)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var debugCard: some View {
        Group {
            if !filteredStats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show detailed heatmap grid", isOn: $showDebugHeatmap)
                        .font(.subheadline)
                    if showDebugHeatmap {
                        BodyHeatmapGrid(stats: filteredStats)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
            }
        }
    }
    
    private func dateRange(for timeframe: Timeframe) -> (Date?, Date?) {
        let end = Date()
        switch timeframe {
        case .all:
            return (nil, nil)
        case .month:
            return (Calendar.current.date(byAdding: .day, value: -30, to: end), end)
        case .threeMonths:
            return (Calendar.current.date(byAdding: .day, value: -90, to: end), end)
        case .year:
            return (Calendar.current.date(byAdding: .year, value: -1, to: end), end)
        }
    }
    
    private func aggregateRegionScores(from stats: [BodyMapEngine.MuscleHeadStats]) -> [BodyRegionID: Double] {
        var totals: [BodyRegionID: Double] = [:]
        
        for stat in stats {
            guard let region = mapToBodyRegion(group: stat.group, head: stat.head) else { continue }
            totals[region, default: 0] += stat.relativeScore
        }
        
        let maxScore = totals.values.max() ?? 0
        guard maxScore > 0 else { return [:] }
        
        var normalized: [BodyRegionID: Double] = [:]
        for (region, value) in totals {
            normalized[region] = max(0, min(100, (value / maxScore) * 100.0))
        }
        return normalized
    }
    
    private func mapToBodyRegion(group: String, head: String) -> BodyRegionID? {
        let g = group.lowercased()
        let h = head.lowercased()
        
        if g.contains("chest") {
            if h.contains("clavicular") || h.contains("upper") { return .chestUpper }
            if h.contains("costal") || h.contains("lower") { return .chestLower }
            return .chestMid
        }
        
        if g.contains("deltoid") || g.contains("delts") || g.contains("shoulder") {
            if h.contains("anterior") || h.contains("front") { return .deltsFront }
            if h.contains("posterior") || h.contains("rear") { return .deltsRear }
            return .deltsSide
        }
        
        if g.contains("biceps") { return .armsBiceps }
        if g.contains("triceps") { return .armsTriceps }
        
        if g.contains("lat") || g == "back" {
            if h.contains("upper") { return .backUpper }
            if h.contains("lower") { return .backLower }
            return .backMid
        }
        
        if g.contains("quad") { return .quadsFront }
        if g.contains("hamstring") { return .hamsBack }
        if g.contains("glute") { return .glutes }
        if g.contains("calf") || g.contains("gastrocnemius") || g.contains("soleus") { return .calves }
        if g.contains("abdom") || g.contains("core") || g.contains("oblique") { return .core }
        
        return nil
    }
    
}

private struct BodyHeatmapGrid: View {
    let stats: [BodyMapEngine.MuscleHeadStats]
    
    private var grouped: [(group: String, heads: [BodyMapEngine.MuscleHeadStats])] {
        let dict = Dictionary(grouping: stats, by: { $0.group })
        return dict.map { key, value in
            (group: key, heads: value.sorted { $0.head < $1.head })
        }
        .sorted { $0.group < $1.group }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(grouped, id: \.group) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.group)
                        .font(.caption).bold()
                    HStack(spacing: 6) {
                        ForEach(group.heads) { stat in
                            VStack(spacing: 2) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(color(for: stat.relativeScore))
                                    .frame(width: 36, height: 36)
                                Text(shortLabel(for: stat.head))
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func color(for score: Double) -> Color {
        let clamped = max(0, min(100, score))
        switch clamped {
        case 0..<20:
            return Color.green.opacity(0.8)
        case 20..<40:
            return Color.yellow.opacity(0.9)
        case 40..<60:
            return Color.blue.opacity(0.85)
        case 60..<80:
            return Color.red.opacity(0.9)
        default:
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        }
    }
    
    private func shortLabel(for head: String) -> String {
        if head.contains("(") {
            return String(head.split(separator: "(").first ?? Substring(head))
        }
        return head
    }
}

private struct MuscleGroupDetailView: View {
    let group: BodyStrengthRankingEngine.GroupRanking
    
    var body: some View {
        List {
            Section("Overview") {
                HStack {
                    Text("Strength tier")
                    Spacer()
                    Text(group.tier.label)
                        .font(.subheadline).bold()
                }
                if let best = group.bestAnchor {
                    HStack {
                        Text("Best anchor lift")
                        Spacer()
                        Text("\(best.exerciseName) – \(String(format: "%.1f", best.bestOneRM)) kg")
                            .multilineTextAlignment(.trailing)
                    }
                }
                if group.isEstimated {
                    Text("No anchor lift logged yet. Tier is estimated from training volume.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !group.anchorResults.isEmpty {
                Section("Anchor lifts") {
                    ForEach(group.anchorResults) { anchor in
                        HStack {
                            Text(anchor.exerciseName)
                            Spacer()
                            Text(String(format: "%.1f kg", anchor.bestOneRM))
                                .font(.caption)
                            Text(anchor.tier.label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Muscle heads") {
                ForEach(group.headRankings) { head in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(head.headName)
                            Spacer()
                            Text(String(format: "%.0f", head.score0to100))
                                .font(.caption).bold()
                        }
                        HStack {
                            Text(head.tier.label)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if head.setCount > 0 {
                                Text("Sets: \(head.setCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(group.displayName)
    }
}

private struct GeneticsControlsView: View {
    @Binding var profile: BodyProfile
    
    private var sortedGroups: [String] {
        profile.muscleGenetics.keys.sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading) {
                Text("Height: \(Int(profile.heightCm)) cm")
                Slider(value: $profile.heightCm, in: 150...200, step: 1)
            }
            VStack(alignment: .leading) {
                Text("Weight: \(Int(profile.weightKg)) kg")
                Slider(value: $profile.weightKg, in: 50...120, step: 1)
            }
            
            VStack(alignment: .leading) {
                Text("Shoulder width")
                Slider(value: $profile.frame.shoulderWidth, in: 0.2...0.8)
            }
            VStack(alignment: .leading) {
                Text("Waist width")
                Slider(value: $profile.frame.waistWidth, in: 0.2...0.8)
            }
            VStack(alignment: .leading) {
                Text("Limb thickness")
                Slider(value: $profile.frame.limbThickness, in: 0.2...0.8)
            }
            
            ForEach(sortedGroups, id: \.self) { group in
                if var settings = profile.muscleGenetics[group] {
                    VStack(alignment: .leading) {
                        Text("\(group) genetics (growth bias)")
                        Slider(
                            value: Binding(
                                get: { settings.growthRateBias },
                                set: { newValue in
                                    settings.growthRateBias = newValue
                                    profile.muscleGenetics[group] = settings
                                }
                            ),
                            in: 0.5...1.5
                        )
                    }
                }
            }
        }
    }
}
