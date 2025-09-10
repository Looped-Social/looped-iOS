import SwiftUI

// MARK: - Looped Font System
extension Font {
    
    // MARK: - Typography Scale (Design System)
    
    static let loopedLargeHeading = Font.custom("Poppins-Regular", size: 52)
    
    static let loopedHeading = Font.custom("Poppins-Regular", size: 36)
    
    static let loopedLogo = Font.custom("Poppins-Bold", size: 24)
    
    static let loopedSubheadMedium = Font.custom("Poppins-Medium", size: 20)
    
    /// Body text (16pt, Regular) - Main content, paragraphs
    static let loopedBody = Font.custom("Poppins-Regular", size: 16)
    
    /// Body medium text (16pt, Medium) - Emphasized body text
    static let loopedBodyMedium = Font.custom("Poppins-Medium", size: 16)
    
    static let loopedSubBodyMedium = Font.custom("Poppins-Medium", size: 14)
    
    static let loopedSubBodyBold = Font.custom("Poppins-Bold", size: 14)
    
    static let loopedSubBodyRegular = Font.custom("Poppins-Regular", size: 14)
    
    static let loopedSmallText = Font.custom("Poppins-Regular", size: 12)

    
    // MARK: - Fallback System Fonts (when custom fonts fail)
    
    static let loopedLogoFallback = Font.largeTitle.bold()
    static let loopedBodyFallback = Font.body
}

// MARK: - Dynamic Type Support
extension Font {
    /// Creates a custom font that scales with Dynamic Type
    /// Usage: Font.loopedScaled("Poppins-Regular", size: 16)
    static func loopedScaled(_ fontName: String, size: CGFloat) -> Font {
        return Font.custom(fontName, size: size, relativeTo: .body)
    }
    
    
    /// Body text with Dynamic Type scaling
    static let loopedBodyScaled = Font.custom("Poppins-Regular", size: 16, relativeTo: .body)
    
    /// Headline text with Dynamic Type scaling
    static let loopedHeadlineScaled = Font.custom("Poppins-SemiBold", size: 17, relativeTo: .headline)
}

// MARK: - Font Loading Utilities
struct LoopedFontLoader {
    
    /// Registers all custom fonts for use in the app
    /// Call this in your App's init() method
    static func registerFonts() {
        let fontNames = [
            "Poppins-Regular",
            "Poppins-Medium", 
            "Poppins-SemiBold",
            "Poppins-Bold",
            "Poppins-ExtraBold"
        ]
        
        for fontName in fontNames {
            registerFont(name: fontName, withExtension: "ttf")
        }
    }
    
    /// Registers a single font file using modern iOS 18+ API
    private static func registerFont(name: String, withExtension ext: String) {
        guard let fontURL = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Poppins") else {
            print("❌ Failed to find font file: \(name).\(ext)")
            return
        }
        
        // Use modern iOS 18+ API
        if #available(iOS 18.0, *) {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
                let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
                print("❌ Failed to register font: \(name). Error: \(errorDescription)")
            } else {
                print("✅ Successfully registered font: \(name)")
            }
        } else {
            // Fallback for iOS < 18.0
            guard let fontData = NSData(contentsOf: fontURL),
                  let provider = CGDataProvider(data: fontData),
                  let font = CGFont(provider) else {
                print("❌ Failed to load font data: \(name).\(ext)")
                return
            }
            
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(font, &error) {
                let errorDescription = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
                print("❌ Failed to register font: \(name). Error: \(errorDescription)")
            } else {
                print("✅ Successfully registered font: \(name)")
            }
        }
    }
}
