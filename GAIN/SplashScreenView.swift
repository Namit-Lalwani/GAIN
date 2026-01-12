import SwiftUI

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -180
    @State private var showContent = false
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            Color.gainBackgroundGradient
                .ignoresSafeArea()
            
            // GAIN Logo with animations
            VStack(spacing: 0) {
                Text("GAIN")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.gainAccent, Color.gainAccentSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: Color.gainAccent.opacity(0.5), radius: 20, x: 0, y: 10)
                
                if showContent {
                    Text("Transform Your Body")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.gainTextSecondary)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            // Entrance animation sequence
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
                rotation = 0
            }
            
            // Show subtitle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeIn(duration: 0.5)) {
                    showContent = true
                }
            }
            
            // Dismiss splash screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isPresented = false
                }
            }
        }
    }
}

