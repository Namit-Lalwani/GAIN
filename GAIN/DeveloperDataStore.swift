import Foundation
import SwiftUI
import Combine

/// Simple offline data store linked to the signed‑in account.
/// Stores files in the app’s Documents directory under a per‑account subfolder.
class DeveloperDataStore: ObservableObject {
    static let shared = DeveloperDataStore()

    @Published var signedInEmail: String?

    private let userDefaults = UserDefaults(suiteName: "com.namitlalwani.GAIN.developerData")

    private let fileManager = FileManager.default

    init() {
        if let email = userDefaults?.string(forKey: "signedInEmail") {
            signedInEmail = email
        }
    }

    func signIn(email: String) {
        signedInEmail = email
        userDefaults?.set(email, forKey: "signedInEmail")
    }

    func signOut() {
        signedInEmail = nil
        userDefaults?.removeObject(forKey: "signedInEmail")
    }

    // MARK: - Per‑account Documents folder

    /// Returns the app’s Documents directory.
    private var documentsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Returns a per‑account subfolder inside Documents.
    /// Uses the email (sanitized) as the folder name.
    private var accountFolderURL: URL {
        let baseName = signedInEmail ?? "anonymous"
        let folderName = baseName
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "@", with: "_at_") ?? baseName
        return documentsURL.appendingPathComponent(folderName)
    }

    /// Stores a file in the per‑account Documents folder.
    func store(data: Data, fileName: String) throws {
        let folderURL = accountFolderURL
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let fileURL = folderURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
    }

    /// Loads a file from the per‑account Documents folder.
    func load(fileName: String) throws -> Data {
        let folderURL = accountFolderURL
        let fileURL = folderURL.appendingPathComponent(fileName)
        return try Data(contentsOf: fileURL)
    }

    /// Deletes the per‑account Documents folder.
    func deleteAccountFolder() throws {
        let folderURL = accountFolderURL
        try fileManager.removeItem(at: folderURL)
    }
}
