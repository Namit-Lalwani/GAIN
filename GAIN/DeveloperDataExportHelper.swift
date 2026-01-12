import Foundation

/// Helper to export all per‑account data from the app’s Documents directory.
/// You can invoke this from Xcode console or add a hidden UI button.
struct DeveloperDataExportHelper {
    static func exportAllAccounts() {
        let fm = FileManager.default
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        do {
            let accountFolders = try fm.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: [.isDirectoryKey])
                .filter { url in
                    var isDir: ObjCBool = false
                    fm.fileExists(atPath: url.path, isDirectory: &isDir)
                    return isDir.boolValue
                }
            for folderURL in accountFolders {
                let accountName = folderURL.lastPathComponent
                print("📂 Exporting account: \(accountName)")
                let files = try fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                for file in files {
                    print("  - \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ Failed to list Documents folders: \(error)")
        }
    }
}
