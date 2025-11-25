import SwiftUI

struct RoutinePlannerView: View {
    @EnvironmentObject var routineStore: RoutineStore
    @State private var selectedDate = Date()
    @State private var showOverrideEditor = false
    @State private var chosenTemplate = "Push"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Weekly simple table
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Template")
                        .font(.headline)
                    ForEach(["Mon","Tue","Wed","Thu","Fri","Sat","Sun"], id: \.self) { day in
                        HStack {
                            Text(day)
                            Spacer()
                            Text(routineStore.weekly[day] ?? "—")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                }
                .padding()

                Divider()

                // Calendar override (simple month view)
                VStack(alignment: .leading) {
                    Text("Calendar Overrides")
                        .font(.headline)

                    DatePicker("Select date", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(.vertical)

                    HStack {
                        Text("Override as")
                        Spacer()
                        Picker("", selection: $chosenTemplate) {
                            ForEach(["Push","Pull","Legs","Upper","Accessory","Rest","Custom"], id: \.self) { t in
                                Text(t)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical)

                    HStack {
                        Button("Set Override") {
                            routineStore.setOverride(for: selectedDate, templateName: chosenTemplate)
                        }
                        Spacer()
                        Button("Remove Override") {
                            routineStore.removeOverride(for: selectedDate)
                        }.foregroundColor(.red)
                    }
                }
                .padding()

                // Show existing overrides
                if !routineStore.overrides.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Active Overrides")
                            .font(.headline)
                        ForEach(Array(routineStore.overrides.keys).sorted(), id: \.self) { key in
                            HStack {
                                Text(key)
                                Spacer()
                                Text(routineStore.overrides[key] ?? "")
                            }
                        }
                    }
                    .padding()
                }

                Spacer()
            }
        }
        .navigationTitle("Planner")
    }
}
