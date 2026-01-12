import SwiftUI
import FirebaseAuth
import GoogleSignIn

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color.gainBackground.ignoresSafeArea()
            
            // Decorative Blobs
            Circle()
                .fill(Color.gainAccent.opacity(0.2))
                .frame(width: 400, height: 400)
                .offset(x: -150, y: -250)
                .blur(radius: 80)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
            
            Circle()
                .fill(Color.gainPrimary.opacity(0.3))
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 300)
                .blur(radius: 60)
                .scaleEffect(isAnimating ? 0.8 : 1.0)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo & Header
                VStack(spacing: 16) {
                    Image(systemName: "bolt.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundStyle(Color.gainAccent)
                        .shadow(color: Color.gainAccent.opacity(0.5), radius: 20)
                    
                    Text("GAIN")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(Color.gainTextPrimary)
                        .tracking(4)
                    
                    Text("Elevate your progress.")
                        .font(.headline)
                        .foregroundStyle(Color.gainTextSecondary)
                }
                .offset(y: isAnimating ? 0 : 20)
                .opacity(isAnimating ? 1 : 0)
                
                Spacer()
                
                // Login Buttons
                VStack(spacing: 20) {
                    Text("Connect your account to sync workouts and see your progress anywhere.")
                        .font(.subheadline)
                        .foregroundStyle(Color.gainTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: handleGoogleSignIn) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)
                            Text("Sign in with Google")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gainVibrantGradient)
                        .cornerRadius(15)
                        .shadow(color: Color.gainPink.opacity(0.35), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 40)
                    
                    if authManager.isLoading {
                        ProgressView()
                            .tint(Color.gainAccent)
                    }
                    
                    if let error = authManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 40)
                    }
                }
                .offset(y: isAnimating ? 0 : 40)
                .opacity(isAnimating ? 1 : 0)
                
                Spacer()
                
                // Footer
                Text("By signing in, you agree to our Terms and Privacy Policy")
                    .font(.caption2)
                    .foregroundStyle(Color.gainTextSecondary.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                isAnimating = true
            }
        }
    }
    
    private func handleGoogleSignIn() {
        authManager.isLoading = true
        authManager.errorMessage = nil
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            authManager.errorMessage = "Could not find root view controller"
            authManager.isLoading = false
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                authManager.errorMessage = error.localizedDescription
                authManager.isLoading = false
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                authManager.errorMessage = "Google sign in failed"
                authManager.isLoading = false
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                         accessToken: user.accessToken.tokenString)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                authManager.isLoading = false
                if let error = error {
                    authManager.errorMessage = error.localizedDescription
                    return
                }
                
                // Success! The AuthManager's listener will update the state
                authManager.syncUserProfile()
            }
        }
    }
}

#Preview {
    LoginView()
}
