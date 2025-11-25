import Foundation

extension FileManager {
    static func documentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func fileURL(_ filename: String) -> URL {
        return documentsDirectory().appendingPathComponent(filename)
    }

    // Async save: encode + write on a background queue so UI never blocks.
    static func save<T: Codable>(_ data: T, to filename: String) {
        let url = fileURL(filename)
        DispatchQueue.global(qos: .background).async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            do {
                let encoded = try encoder.encode(data)
                try encoded.write(to: url, options: .atomic)
                // optional: print("Saved \(filename)")
            } catch {
                // print but don't crash UI
                print("❌ Save error for \(filename):", error)
            }
        }
    }

    // Async load with completion on main queue
    static func loadAsync<T: Codable>(_ type: T.Type, from filename: String, completion: @escaping (T?) -> Void) {
        let url = fileURL(filename)
        DispatchQueue.global(qos: .background).async {
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode(T.self, from: data)
                DispatchQueue.main.async { completion(decoded) }
            } catch {
                print("❌ Load error for \(filename):", error)
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // Compatibility synchronous load (rarely used) kept but safe — use only at app start if needed.
    static func load<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        let url = fileURL(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("❌ Load error for \(filename):", error)
            return nil
        }
    }
}

