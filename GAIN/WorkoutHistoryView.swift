import SwiftUI

struct WorkoutHistoryView: View {
    @ObservedObject private var store = WorkoutStore.shared
    @State private var showExportAlert = false
    @State private var exportURL: URL?
    @State private var showAddPastWorkout = false

    var body: some View {
        NavigationView {
            List {
                if store.records.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("No workouts saved yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Complete your first workout to see it here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(store.records) { w in
                        NavigationLink(destination: WorkoutHistoryDetailView(record: w)) {
                            HStack(spacing: 12) {
                                // Icon with date
                                VStack(spacing: 2) {
                                    Text(w.start, format: .dateTime.day())
                                        .font(.title2).bold()
                                    Text(w.start, format: .dateTime.month(.abbreviated))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 50)
                                .padding(.vertical, 8)
                                .background(Color.teal.opacity(0.1))
                                .cornerRadius(10)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(w.templateName ?? "Custom Workout")
                                        .font(.headline)
                                    
                                    HStack(spacing: 16) {
                                        Label("\(w.exercises.count)", systemImage: "list.bullet")
                                        Label(formatTimeInterval(w.duration), systemImage: "timer")
                                        Label(String(format: "%.0f kg", w.totalVolume), systemImage: "scalemass")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.delete(id: store.records[index].id)
                        }
                    }
                }
            }
            .navigationTitle("Workout History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showAddPastWorkout = true }) {
                            Image(systemName: "plus")
                        }
                        Button(action: exportCSV) {
                            Image(systemName: "square.and.arrow.up")
                        }
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
            .sheet(isPresented: $showAddPastWorkout) {
                NavigationView {
                    AddPastWorkoutView { record in
                        store.add(record)
                        showAddPastWorkout = false
                    } onCancel: {
                        showAddPastWorkout = false
                    }
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
                HStack { Text("Total Volume"); Spacer(); Text(String(format: "%.0f", record.totalVolume)) }
            }

            Section("Exercises") {
                ForEach(record.exercises) { ex in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.name).font(.headline)

                        if let exNotes = ex.notes, !exNotes.isEmpty {
                            Text(exNotes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ForEach(ex.sets) { s in
                            VStack(alignment: .leading, spacing: 4) {
                                // Safe numeric formatting using the `format:` interpolation to avoid nested quotes
                                let sideLabel: String = {
                                    switch s.side {
                                    case .both: return ""
                                    case .left: return " (L)"
                                    case .right: return " (R)"
                                    }
                                }()
                                Text("Reps: \(s.reps)  •  Weight: \(s.weight, format: .number.precision(.fractionLength(1)))\(sideLabel)")
                                    .font(.subheadline)

                                if let hr = s.heartRateAtCompletion {
                                    Text("HR: \(hr) bpm")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let note = s.note, !note.isEmpty {
                                    Text("Note: \(note)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let completedAt = s.completedAt {
                                    Text("Done: \(completedAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption2)
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

// MARK: - Add Past Workout Form
struct AddPastWorkoutView: View {
    @State private var name: String = ""
    @State private var date: Date = Date()
    @State private var durationMinutes: String = "45"
    @State private var notes: String = ""

    let onSave: (WorkoutRecord) -> Void
    let onCancel: () -> Void

    var body: some View {
        Form {
            Section(header: Text("Basic Info")) {
                TextField("Routine name", text: $name)
                DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                HStack {
                    TextField("Duration", text: $durationMinutes)
                        .keyboardType(.numberPad)
                    Text("min")
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Notes")) {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
            }
        }
        .navigationTitle("Add Past Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let duration = (Int(durationMinutes) ?? 0) * 60
        let record = WorkoutRecord(
            templateName: trimmedName.isEmpty ? nil : trimmedName,
            start: date,
            end: duration > 0 ? date.addingTimeInterval(TimeInterval(duration)) : nil,
            duration: TimeInterval(duration),
            exercises: [],
            notes: notes.isEmpty ? nil : notes
        )
        onSave(record)
    }
}
