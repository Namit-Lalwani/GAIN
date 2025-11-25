import Foundation

// MARK: - Persistence Configuration
public enum PersistenceType {
    case local
    case supabase
}

public struct PersistenceConfig {
    public static var currentType: PersistenceType {
        // Check for Supabase environment variables
        if let _ = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           let _ = ProcessInfo.processInfo.environment["SUPABASE_KEY"] {
            return .supabase
        }
        // Default to local
        return .local
    }
    
    public static var supabaseURL: String? {
        ProcessInfo.processInfo.environment["SUPABASE_URL"]
    }
    
    public static var supabaseKey: String? {
        ProcessInfo.processInfo.environment["SUPABASE_KEY"]
    }
    
    // For Info.plist configuration (alternative to environment variables)
    public static func loadFromInfoPlist() -> (url: String?, key: String?) {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            return (nil, nil)
        }
        
        let url = plist["SUPABASE_URL"] as? String
        let key = plist["SUPABASE_KEY"] as? String
        return (url, key)
    }
}

// MARK: - Persistence Factory
public func createPersistenceAdapter() -> PersistenceAdapter {
    let config = PersistenceConfig.loadFromInfoPlist()
    
    if let url = PersistenceConfig.supabaseURL ?? config.url,
       let key = PersistenceConfig.supabaseKey ?? config.key {
        return SupabasePersistenceAdapter(url: url, key: key)
    }
    
    return LocalPersistenceAdapter()
}





