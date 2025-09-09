import SwiftUI

// MARK: - Looped Font System
extension Font {
    
    // MARK: - Typography Scale (Design System)
    
    
    static let loopedLogo = Font.custom("Poppins-Bold", size: 24)
    /// Large title text (32pt, Bold) - Hero sections, main headings
    static let loopedLargeTitle = Font.custom("Poppins-Bold", size: 32)
    
    /// Title text (28pt, Bold) - Screen titles, major sections
    static let loopedTitle = Font.custom("Poppins-Bold", size: 28)
    
    /// Title 2 text (22pt, Bold) - Section headers
    static let loopedTitle2 = Font.custom("Poppins-Bold", size: 22)
    
    /// Title 3 text (20pt, Semibold) - Subsection headers
    static let loopedTitle3 = Font.custom("Poppins-SemiBold", size: 20)
    
    /// Headline text (17pt, Semibold) - List headers, emphasized text
    static let loopedHeadline = Font.custom("Poppins-SemiBold", size: 17)
    
    /// Body text (16pt, Regular) - Main content, paragraphs
    static let loopedBody = Font.custom("Poppins-Regular", size: 16)
    
    /// Body medium text (16pt, Medium) - Emphasized body text
    static let loopedBodyMedium = Font.custom("Poppins-Medium", size: 16)
    
    /// Callout text (15pt, Regular) - Secondary content
    static let loopedCallout = Font.custom("Poppins-Regular", size: 15)
    
    /// Subhead text (14pt, Regular) - Supporting text, descriptions
    static let loopedSubhead = Font.custom("Poppins-Regular", size: 14)
    
    /// Subhead medium text (14pt, Medium) - Emphasized supporting text
    static let loopedSubheadMedium = Font.custom("Poppins-Medium", size: 14)
    
    /// Footnote text (13pt, Regular) - Fine print, metadata
    static let loopedFootnote = Font.custom("Poppins-Regular", size: 13)
    
    /// Caption text (12pt, Regular) - Image captions, timestamps
    static let loopedCaption = Font.custom("Poppins-Regular", size: 12)
    
    /// Caption 2 text (11pt, Regular) - Smallest text, labels
    static let loopedCaption2 = Font.custom("Poppins-Regular", size: 11)
    
    // MARK: - UI-Specific Fonts
    
    /// Button text (16pt, Semibold) - All button labels
    static let loopedButton = Font.custom("Poppins-SemiBold", size: 16)
    
    /// Navigation title (17pt, Semibold) - Navigation bar titles
    static let loopedNavTitle = Font.custom("Poppins-SemiBold", size: 17)
    
    /// Tab bar text (10pt, Medium) - Tab bar labels
    static let loopedTabBar = Font.custom("Poppins-Medium", size: 10)
    
    // MARK: - Fallback System Fonts (when custom fonts fail)
    
    static let loopedLargeTitleFallback = Font.largeTitle.bold()
    static let loopedTitleFallback = Font.title.bold()
    static let loopedTitle2Fallback = Font.title2.bold()
    static let loopedTitle3Fallback = Font.title3.weight(.semibold)
    static let loopedHeadlineFallback = Font.headline
    static let loopedBodyFallback = Font.body
    static let loopedCalloutFallback = Font.callout
    static let loopedSubheadFallback = Font.subheadline
    static let loopedFootnoteFallback = Font.footnote
    static let loopedCaptionFallback = Font.caption
    static let loopedCaption2Fallback = Font.caption2
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
    
    /// Lists all available fonts (useful for debugging)
    static func printAvailableFonts() {
        for family in UIFont.familyNames.sorted() {
            print("Font Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family) {
                print("  - \(name)")
            }
        }
    }
}
