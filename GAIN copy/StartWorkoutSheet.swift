import SwiftUI

// MARK: - Start Workout Sheet
struct StartWorkoutSheet: View {
    @EnvironmentObject var routineStore: RoutineStore
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Today's assigned")) {
                    Text(routineStore.templateFor(date: Date()))
                }

                Section {
                    Button("Start Today's Routine") {
                        // TODO: start routine
                        presentationMode.wrappedValue.dismiss()
                    }

                    Button("Start Empty Workout") {
                        // TODO: start empty
                        presentationMode.wrappedValue.dismiss()
                    }

                    NavigationLink("Start From Template") {
                        TemplatePickerView()
                    }
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Template Picker
struct TemplatePickerView: View {
    var body: some View {
        List {
            ForEach(["Push","Pull","Legs","Upper","Accessory","Rest","Custom"], id: \.self) { t in
                Text(t)
            }
        }
        .navigationTitle("Choose Template")
    }
}

// MARK: - Today Summary
struct TodaySummaryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Today's Summary")
                    .font(.title2).bold()

                Text("Quick stats will appear here.")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
        }
    }
}

