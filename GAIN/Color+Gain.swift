import SwiftUI

// Global design system colors for GAIN (dark-mode only)
extension Color {
    // Core brand colors
    static let gainBackground = Color(red: 0x2d/255.0, green: 0x02/255.0, blue: 0x43/255.0)   // #2d0243
    static let gainPrimary    = Color(red: 0x50/255.0, green: 0x13/255.0, blue: 0x6b/255.0)   // #50136b
    static let gainAccent     = Color(red: 0xba/255.0, green: 0xab/255.0, blue: 0xd9/255.0)   // #baabd9
    static let gainAccentSoft = Color(red: 0xc9/255.0, green: 0xc2/255.0, blue: 0xe7/255.0)   // #c9c2e7
    
    // New Vibrant Colors
    static let gainPink   = Color(red: 0xFF/255.0, green: 0x2D/255.0, blue: 0x55/255.0)       // #FF2D55
    static let gainPurple = Color(red: 0x8E/255.0, green: 0x44/255.0, blue: 0xAD/255.0)       // #8E44AD
    static let gainPinkGradient = [Color(red: 0xFF/255.0, green: 0x00/255.0, blue: 0x80/255.0), Color(red: 0x79/255.0, green: 0x28/255.0, blue: 0xCA/255.0)]

    // Text colors
    static let gainTextPrimary   = Color.white
    static let gainTextSecondary = Color.white.opacity(0.7)

    // Surfaces
    static let gainCard      = Color.gainPrimary.opacity(0.7)
    static let gainCardSoft  = Color.gainPrimary.opacity(0.4)

    // Gradients helpers
    static var gainPrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [Color.gainPrimary, Color.gainAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var gainVibrantGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0xFF/255.0, green: 0x00/255.0, blue: 0x7B/255.0), Color(red: 0x70/255.0, green: 0x00/255.0, blue: 0xFF/255.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var gainBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.gainBackground, Color.gainPrimary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
