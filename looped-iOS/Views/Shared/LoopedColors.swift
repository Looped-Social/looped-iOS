import SwiftUI

// MARK: - Looped App Color Extensions
extension Color {
    // MARK: - Primary Colors
    static let loopedPrimary = Color("PrimaryColor")
    static let loopedSecondary = Color("SecondaryColor")
    static let loopedDestructive = Color("DestructiveColor")
    
    // MARK: - Background Colors
    static let loopedBackground = Color("BackgroundColor")
    static let loopedSurface = Color("SurfaceColor")
    
    // MARK: - Text Colors
    static let loopedTextPrimary = Color("TextPrimaryColor")
    static let loopedTextSecondary = Color("TextSecondaryColor")
    
    // MARK: - Accent Colors
    static let loopedAccent = Color("AccentColor")
    
    // MARK: - Fallback Colors (if Asset Catalog colors aren't created yet)
    static let loopedPrimaryFallback = Color.red
    static let loopedSecondaryFallback = Color.blue
    static let loopedDestructiveFallback = Color.red.opacity(0.9)
}

// MARK: - Usage Guide
/*
 To create these colors in Assets.xcassets:
 
 1. Open Assets.xcassets in Xcode
 2. Right-click → "New Color Set"
 3. Name it (e.g., "PrimaryColor")
 4. Set colors for:
    - Any Appearance (default color)
    - Dark Appearance (for dark mode support)
 
 Recommended color names to create:
 - PrimaryColor      (main brand color - currently red)
 - SecondaryColor    (secondary actions)
 - DestructiveColor  (delete, destructive actions)
 - BackgroundColor   (main background)
 - SurfaceColor      (card backgrounds, elevated surfaces)
 - TextPrimaryColor  (main text)
 - TextSecondaryColor (secondary text)
 - AccentColor       (highlights, selections)
 
 Usage in SwiftUI:
 .backgroundColor(.loopedPrimary)
 .foregroundColor(.loopedTextPrimary)
 */