import SwiftUI

// MARK: - Looped App Color Extensions
extension Color {
    // MARK: - Primary Colors
    static let loopedPrimary = Color("PrimaryColor")
    static let loopedSecondary = Color("SecondaryColor")
    static let loopedContrast = Color("ContrastColor")

    static func loopedAccent(isAnonymousMode: Bool) -> Color {
        isAnonymousMode ? .loopedSecondary : .loopedPrimary
    }
    
    // MARK: - Background Colors
    static let loopedBackground = Color("BackgroundColor")
    static let loopedMutedBackground = Color("MutedBackground")
    static let loopedMessageColor = Color("MessageColor")
    static let loopedMessageMutedColor = Color("MessageColorMuted")

    // MARK: - Text Colors
    static let loopedTextPrimary = Color("TextPrimaryColor")
    static let loopedTextSecondary = Color("TextSecondaryColor")
    static let loopedTextStrong = Color("StrongText")
    
    // MARK: - System Color Tokens (Centralized)
    static let loopedWhite = Color("White")
    static let loopedBlack = Color("Black")
    static let loopedGray = Color("TextSecondaryColor")
    static let loopedClear = Color.clear

    static let loopedError = Color("ErrorColor")
    static let loopedSuccess = Color("SuccessColor")
    static let loopedWarning = Color("WarningColor")
    
    

}
