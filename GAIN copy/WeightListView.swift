import SwiftUI

struct WeightListView: View {
    @EnvironmentObject var weightStore: WeightStore

    var body: some View {
        VStack {
            List {
                ForEach(weightStore.entries) { entry in
                    Text("\(entry.date, style: .date) – \(entry.weightKg, specifier: "%.1f") kg")
                }
            }

            Button("+ Add Weight") {
                // Will implement later
            }
            .padding()
        }
        .navigationTitle("Body Weight")
    }
}
