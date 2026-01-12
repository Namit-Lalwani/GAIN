import SwiftUI

struct ExerciseLibraryView: View {
    @EnvironmentObject var exerciseLibrary: ExerciseLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    var onSelect: (ExerciseDefinition) -> Void

    var body: some View {
        List {
            ForEach(currentList) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline)
                        if let primary = exercise.primaryMuscles, !primary.isEmpty {
                            Text(primary.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercise Library")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
    }

    private var currentList: [ExerciseDefinition] {
        exerciseLibrary.filtered(by: searchText)
    }
}
