import Foundation
import FirebaseAuth
import GoogleSignIn
import FirebaseFirestore
import Combine

/// Manages authentication state and logic for GAIN.
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private lazy var db = Firestore.firestore()
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    
    private init() {
        // Listen for authentication state changes
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = (user != nil)
                
                if let email = user?.email {
                    // Update DeveloperDataStore as well for backward compatibility or local usage
                    DeveloperDataStore.shared.signIn(email: email)
                } else {
                    DeveloperDataStore.shared.signOut()
                }
            }
        }
    }
    
    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    /// Sign out from Firebase and Google
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    /// Sync user profile data to Firestore
    func syncUserProfile() {
        guard let user = currentUser else { return }
        
        let userData: [String: Any] = [
            "uid": user.uid,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "photoURL": user.photoURL?.absoluteString ?? "",
            "lastLogin": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("Error syncing user profile: \(error.localizedDescription)")
            }
        }
    }
}
