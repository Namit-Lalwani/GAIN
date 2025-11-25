import SwiftUI

struct WeeklyRoutinePlannerView: View {
    @EnvironmentObject var templateStore: TemplateStore
    @AppStorage("weeklyAssignments") private var weeklyAssignmentsData: Data = Data()

    @State private var assignments: [String: UUID] = [:]

    private let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var body: some View {
        Form {
            Section(header: Text("Assign Templates to Days")) {
                ForEach(days, id: \.self) { day in
                    Picker(day, selection: Binding(
                        get: { assignments[day] ?? UUID() },
                        set: { assignments[day] = $0 }
                    )) {
                        Text("Rest Day").tag(UUID())
                        ForEach(templateStore.templates) { t in
                            Text(t.name).tag(t.id)
                        }
                    }
                }
            }

            Section {
                Button("Save Weekly Plan") {
                    saveAssignments()
                }
                .font(.headline)
            }

            Section(header: Text("Today's Plan")) {
                let today = getToday()
                if let templateID = assignments[today],
                   let template = templateStore.templates.first(where: { $0.id == templateID }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today is \(today)")
                        Text("Workout: \(template.name)").font(.headline)
                        NavigationLink("Start Workout", destination: Text("Launch Workout with \(template.name)"))
                    }
                } else {
                    Text("Today is \(today)")
                    Text("Rest Day").foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Routine Planner")
        .onAppear(perform: loadAssignments)
    }

    func getToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }

    func saveAssignments() {
        if let data = try? JSONEncoder().encode(assignments) {
            weeklyAssignmentsData = data
        }
    }

    func loadAssignments() {
        if let decoded = try? JSONDecoder().decode([String: UUID].self, from: weeklyAssignmentsData) {
            assignments = decoded
        }
    }
}

#Preview {
    WeeklyRoutinePlannerView()
        .environmentObject(TemplateStore())
}
