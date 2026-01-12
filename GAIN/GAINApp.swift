import SwiftUI
import os.log
import FirebaseCore
import FirebaseAuth

@main
struct GAINApp: App {
    @Environment(\.scenePhase) private var scenePhase
    // MARK: - State Objects
    @StateObject private var workoutStore = WorkoutStore.shared
    @StateObject private var sessionStore = SessionStore.shared
    @StateObject private var weightStore = WeightStore.shared
    @StateObject private var templateStore = TemplateStore()
    @StateObject private var exerciseLibraryStore = ExerciseLibraryStore()
    @StateObject private var bodyProfileStore = BodyProfileStore()
    @StateObject private var waterStore = WaterStore()
    @StateObject private var waterIntakeStore = WaterIntakeStore()
    @StateObject private var calorieStore = CalorieStore()
    @StateObject private var stepsStore = StepsStore()
    @StateObject private var sleepStore = SleepStore()
    @StateObject private var goalsStore = GoalsStore()
    @StateObject private var heartRateStore = HeartRateStore.shared
    @StateObject private var dailyStatsStore = DailyStatsStore.shared
    @StateObject private var stepsSleepHealthStore = StepsSleepHealthStore.shared
    @StateObject private var overloadSettingsStore = ProgressiveOverloadSettingsStore.shared
    @StateObject private var developerData = DeveloperDataStore.shared
    @StateObject private var authManager = AuthManager.shared
      


    // MARK: - State
    @State private var isInitialized = false
    @State private var showSplash = true
    @State private var error: Error?
    
    // MARK: - Logger
    private let logger = Logger(
        subsystem: "com.yourdomain.GAIN",
        category: String(describing: GAINApp.self)
    )
    
    // MARK: - Initialization
    init() {
        // Configure app appearance and error handling
        configureAppearance()
        setupErrorHandling()
        
        // Initialize Firebase
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreenView(isPresented: $showSplash)
                        .transition(.opacity)
                        .zIndex(2)
                }
                
                if !showSplash {
                    if authManager.isAuthenticated {
                        MainTabView()
                            .environmentObject(workoutStore)
                            .environmentObject(sessionStore)
                            .environmentObject(weightStore)
                            .environmentObject(templateStore)
                            .environmentObject(exerciseLibraryStore)
                            .environmentObject(bodyProfileStore)
                            .environmentObject(waterStore)
                            .environmentObject(waterIntakeStore)
                            .environmentObject(calorieStore)
                            .environmentObject(stepsStore)
                            .environmentObject(sleepStore)
                            .environmentObject(goalsStore)
                            .environmentObject(heartRateStore)
                            .environmentObject(dailyStatsStore)
                            .environmentObject(stepsSleepHealthStore)
                            .environmentObject(overloadSettingsStore)
                            .environmentObject(developerData)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                            .zIndex(1)
                    } else {
                        LoginView()
                            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .opacity))
                            .zIndex(1)
                    }
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error?.localizedDescription ?? "An unknown error occurred")
            }
            .task {
                await initializeApp()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    stepsSleepHealthStore.syncToday()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func initializeApp() async {
        // Initialize SyncManager
        _ = SyncManager.shared
        
        // Initialize any async components here
        
        // Mark initialization as complete
        isInitialized = true
    }
    
    private func setupErrorHandling() {
        // Set up any global error handling here if needed
        // For now, we'll rely on the error state in the UI
    }
    
    private func saveCrashLog(message: String) {
        do {
            let logsDirectory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Logs")
            
            try FileManager.default.createDirectory(
                at: logsDirectory,
                withIntermediateDirectories: true
            )
            
            let formatter = ISO8601DateFormatter()
            let logFile = logsDirectory.appendingPathComponent("crash_\(formatter.string(from: Date())).log")
            
            try message.write(to: logFile, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save crash log: \(error)")
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }

    // MARK: - Export helper (accessible from Xcode console)

    /// Call this from Xcode console to dump all per-account Documents folders.
    /// Example: `GAINApp.dumpAllAccounts()`
    static func dumpAllAccounts() {
        DeveloperDataExportHelper.exportAllAccounts()
    }
}
