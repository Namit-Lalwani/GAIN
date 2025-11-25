import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject var templateStore: TemplateStore

    var body: some View {
        NavigationView {
            List {
                // Add template
                Section {
                    NavigationLink {
                        TemplateEditorView(template: TemplateModel())
                    } label: {
                        Label("Add New Template", systemImage: "plus.circle")
                    }
                }

                // User Templates
                Section(header: Text("Your Templates")) {
                    if templateStore.templates.isEmpty {
                        Text("No templates yet. Tap + to create one.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(templateStore.templates) { t in
                            NavigationLink {
                                TemplateEditorView(template: t)
                            } label: {
                                HStack {
                                    Text(t.name)
                                    Spacer()
                                    Text("\(t.exercises.count) exercises")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                }

                // Recommended
                Section(header: Text("Recommended")) {
                    ForEach(["Push", "Pull", "Legs", "Upper", "Full Body"], id: \.self) { r in
                        Text(r)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Templates")
            .toolbar {
                EditButton()
            }
        }
    }

    // Delete handler
    private func deleteTemplates(at offsets: IndexSet) {
        offsets.forEach { i in
            let id = templateStore.templates[i].id
            templateStore.delete(id: id)
        }
    }
}
