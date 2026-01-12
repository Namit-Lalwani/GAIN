import SwiftUI

struct SettingsView: View {
    @StateObject private var developerData = DeveloperDataStore.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account")) {
                    Button(action: {
                        // TODO: implement Google Sign‑In
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)
                            Text("Sign in with Google")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        // TODO: implement Apple Sign‑In
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .foregroundColor(.black)
                                .font(.title2)
                            Text("Sign in with Apple")
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section(header: Text("My Account")) {
                    HStack {
                        Text("Signed in as:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(developerData.signedInEmail ?? "Not signed in")
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                    }
                }

                Section(header: Text("Developer Data")) {
                    Text("All app data is stored locally on this device in a private folder linked to your signed‑in account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

