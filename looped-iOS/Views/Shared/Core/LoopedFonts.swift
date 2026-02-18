import SwiftUI

enum LoopedFontWeight {
    case regular
    case medium
    case semibold
    case bold
    case extrabold
}

// MARK: - Looped Font System
extension Font {
    
    // MARK: - Typography Scale (Design System)
    
    
    static let loopedSuperLargeHeading = Font.custom("Poppins-Regular", size: 68)

    static let loopedLargeHeading = Font.custom("Poppins-Regular", size: 52)
    
    static let loopedHeading = Font.custom("Poppins-Regular", size: 36)
    
    static let loopedLogo = Font.custom("Poppins-Bold", size: 24)
    
    static let loopedSubheadMedium = Font.custom("Poppins-Medium", size: 20)
    
    static let loopedHeadingMedium = Font.custom("Poppins-Medium", size: 24)
    
    
    static let loopedHeadingMedium32 = Font.custom("Poppins-Medium", size: 32)
    
    static let loopedHeadingMedium28 = Font.custom("Poppins-Medium", size: 28)
    
    static let loopedHeaderStrong = Font.custom("Poppins-SemiBold", size: 32)

    /// Body text (16pt, Regular) - Main content, paragraphs
    static let loopedBody = Font.custom("Poppins-Regular", size: 16)
    
    static let loopedBody24 = Font.custom("Poppins-Regular", size: 24)

    /// Body medium text (16pt, Medium) - Emphasized body text
    static let loopedBodyMedium = Font.custom("Poppins-Medium", size: 16)
    
    static let loopedSubBodyMedium = Font.custom("Poppins-Medium", size: 14)
    
    static let loopedSubBodyBold = Font.custom("Poppins-Bold", size: 14)
    
    static let loopedSubBodyRegular = Font.custom("Poppins-Regular", size: 14)

    static let loopedSmallText = Font.custom("Poppins-Regular", size: 12)
    static let loopedSmallTextMedium = Font.custom("Poppins-Medium", size: 12)

    /// Body strong text (16pt, SemiBold) - Strong emphasized body text
    static let loopedBodyStrong = Font.custom("Poppins-SemiBold", size: 16)
    static let loopedBodyStrong32 = Font.custom("Poppins-SemiBold", size: 32)
    static let loopedHeaderProfile = Font.custom("Poppins-SemiBold", size: 24)

    // MARK: - Comments Typography
    static let loopedCommentsScreenTitle = Font.custom("Poppins-SemiBold", size: 24)
    static let loopedCommentsPostBody = Font.custom("Poppins-Regular", size: 18)
    static let loopedCommentsPostAuthor = Font.custom("Poppins-Medium", size: 20)
    static let loopedCommentsPostMeta = Font.custom("Poppins-Regular", size: 15)
    static let loopedCommentsBody = Font.custom("Poppins-Regular", size: 16)
    static let loopedCommentsAuthor = Font.custom("Poppins-Medium", size: 16)
    static let loopedCommentsMeta = Font.custom("Poppins-Regular", size: 13)
    static let loopedCommentsMetaStrong = Font.custom("Poppins-Medium", size: 13)
    static let loopedCommentsAction = Font.custom("Poppins-Medium", size: 13)
    static let loopedCommentsReplyBody = Font.custom("Poppins-Regular", size: 15)
    static let loopedCommentsReplyAuthor = Font.custom("Poppins-Medium", size: 15)
    static let loopedCommentsReplyMeta = Font.custom("Poppins-Regular", size: 12)
    static let loopedCommentsReplyMetaStrong = Font.custom("Poppins-Medium", size: 12)
    static let loopedCommentsReplyAction = Font.custom("Poppins-Medium", size: 12)

    
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

    static func loopedCustom(_ weight: LoopedFontWeight = .regular, size: CGFloat) -> Font {
        return Font.custom(loopedFontName(for: weight), size: size)
    }

    static func loopedCustom(
        _ weight: LoopedFontWeight = .regular,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        return Font.custom(loopedFontName(for: weight), size: size, relativeTo: textStyle)
    }

    /// SF Symbols + iconography should use the system font to match native rendering.
    static func loopedSymbol(_ weight: LoopedFontWeight = .medium, size: CGFloat) -> Font {
        Font.system(size: size, weight: loopedSystemWeight(for: weight))
    }

    /// Monospaced code strings (e.g., verification codes).
    static let loopedMonospaceCode = Font.system(.headline, design: .monospaced)
    
    
    /// Body text with Dynamic Type scaling
    static let loopedBodyScaled = Font.custom("Poppins-Regular", size: 16, relativeTo: .body)
    
    /// Headline text with Dynamic Type scaling
    static let loopedHeadlineScaled = Font.custom("Poppins-SemiBold", size: 17, relativeTo: .headline)

    static let loopedSubheadlineScaled = Font.custom("Poppins-Regular", size: 15, relativeTo: .subheadline)
    static let loopedCaptionScaled = Font.custom("Poppins-Regular", size: 12, relativeTo: .caption)
    static let loopedTitle2Scaled = Font.custom("Poppins-Regular", size: 22, relativeTo: .title2)

    private static func loopedFontName(for weight: LoopedFontWeight) -> String {
        switch weight {
        case .regular:
            return "Poppins-Regular"
        case .medium:
            return "Poppins-Medium"
        case .semibold:
            return "Poppins-SemiBold"
        case .bold:
            return "Poppins-Bold"
        case .extrabold:
            return "Poppins-ExtraBold"
        }
    }

    private static func loopedSystemWeight(for weight: LoopedFontWeight) -> Font.Weight {
        switch weight {
        case .regular:
            return .regular
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .bold:
            return .bold
        case .extrabold:
            return .heavy
        }
    }
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
            return
        }
        
        // Use modern iOS 18+ API
        if #available(iOS 18.0, *) {
            var error: Unmanaged<CFError>?
            _ = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            if let error = error {
                _ = error.takeRetainedValue()
            }
        } else {
            // Fallback for iOS < 18.0
            guard let fontData = NSData(contentsOf: fontURL),
                  let provider = CGDataProvider(data: fontData),
                  let font = CGFont(provider) else {
                return
            }
            
            var error: Unmanaged<CFError>?
            _ = CTFontManagerRegisterGraphicsFont(font, &error)
            if let error = error {
                _ = error.takeRetainedValue()
            }
        }
    }
}
