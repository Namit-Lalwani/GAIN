import SwiftUI

struct WorkoutHistoryView: View {
    @ObservedObject private var store = WorkoutStore.shared
    @State private var showExportAlert = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationView {
            List {
                if store.workouts.isEmpty {
                    Text("No workouts saved yet")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.workouts) { w in
                        NavigationLink(destination: WorkoutHistoryDetailView(record: w)) {
                            VStack(alignment: .leading) {
                                Text(w.templateName ?? "Custom Workout")
                                    .font(.headline)

                                Text("\(w.start.formatted(date: .abbreviated, time: .shortened))  •  \(formatTimeInterval(w.duration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
            .navigationTitle("Workout History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportCSV) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .alert("Exported CSV", isPresented: $showExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                if let url = exportURL {
                    Text("CSV saved to:\n\(url.path)")
                } else {
                    Text("Export failed.")
                }
            }
        }
    }

    private func exportCSV() {
        Task {
            do {
                let url = try await store.exportCSV()
                exportURL = url
                showExportAlert = true
            } catch {
                exportURL = nil
                showExportAlert = true
            }
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - DETAIL VIEW
struct WorkoutHistoryDetailView: View {
    let record: WorkoutRecord

    var body: some View {
        Form {
            Section("Overview") {
                HStack { Text("Template"); Spacer(); Text(record.templateName ?? "Custom") }
                HStack { Text("Date"); Spacer(); Text(record.start.formatted(date: .abbreviated, time: .shortened)) }
                HStack { Text("Duration"); Spacer(); Text(formatTimeInterval(record.duration)) }
                HStack { Text("Total Volume"); Spacer(); Text(String(format: "%.0f kg", record.totalVolume)) }
            }

            Section("Exercises") {
                ForEach(record.exercises) { ex in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.name).font(.headline)

                        ForEach(ex.sets) { s in
                            VStack(alignment: .leading) {
                                Text("Reps: \(s.reps) • Weight: \(String(format: \"%.1f\", s.weight))")
                                if let hr = s.heartRateAtCompletion {
                                    Text("HR: \(Int(hr)) bpm")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Notes") {
                Text(record.notes ?? "No notes").foregroundColor(.secondary)
            }
        }
        .navigationTitle("Workout Summary")
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
