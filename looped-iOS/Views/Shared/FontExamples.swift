import SwiftUI

// MARK: - Font Usage Examples
struct FontExamples: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // MARK: - Typography Scale
                VStack(alignment: .leading, spacing: 16) {
                    Text("Typography Scale")
                        .font(.loopedTitle3)
                        .foregroundColor(.loopedTextPrimary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Large Title")
                            .font(.loopedLargeTitle)
                        
                        Text("Title")
                            .font(.loopedTitle)
                        
                        Text("Title 2")
                            .font(.loopedTitle2)
                        
                        Text("Title 3")
                            .font(.loopedTitle3)
                        
                        Text("Headline")
                            .font(.loopedHeadline)
                        
                        Text("Body Text - This is the main text used for content and paragraphs throughout the app.")
                            .font(.loopedBody)
                        
                        Text("Body Medium - Emphasized body text for important content.")
                            .font(.loopedBodyMedium)
                        
                        Text("Callout - Secondary content and supporting information.")
                            .font(.loopedCallout)
                        
                        Text("Subhead - Supporting text and descriptions.")
                            .font(.loopedSubhead)
                        
                        Text("Subhead Medium - Emphasized supporting text.")
                            .font(.loopedSubheadMedium)
                        
                        Text("Footnote - Fine print and metadata.")
                            .font(.loopedFootnote)
                        
                        Text("Caption - Image captions and timestamps.")
                            .font(.loopedCaption)
                        
                        Text("Caption 2 - Smallest text for labels.")
                            .font(.loopedCaption2)
                    }
                }
                
                Divider()
                
                // MARK: - UI Component Fonts
                VStack(alignment: .leading, spacing: 16) {
                    Text("UI Component Fonts")
                        .font(.loopedTitle3)
                        .foregroundColor(.loopedTextPrimary)
                    
                    VStack(spacing: 12) {
                        // Button example
                        Button("Button Text") {
                            print("Button tapped")
                        }
                        .font(.loopedButton)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.loopedPrimary)
                        .cornerRadius(8)
                        
                        // Navigation title example
                        HStack {
                            Text("Navigation Title")
                                .font(.loopedNavTitle)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Tab bar example
                        HStack {
                            ForEach(["Home", "Messages", "Profile"], id: \.self) { item in
                                Text(item)
                                    .font(.loopedTabBar)
                                if item != "Profile" { Spacer() }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Divider()
                
                // MARK: - Dynamic Type Examples
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dynamic Type Support")
                        .font(.loopedTitle3)
                        .foregroundColor(.loopedTextPrimary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This text scales with system settings")
                            .font(.loopedBodyScaled)
                        
                        Text("This headline also scales")
                            .font(.loopedHeadlineScaled)
                        
                        Text("Custom scaled font example")
                            .font(.loopedScaled("Poppins-Medium", size: 18))
                    }
                }
                
                Divider()
                
                // MARK: - Usage Examples in Context
                VStack(alignment: .leading, spacing: 16) {
                    Text("Real Usage Examples")
                        .font(.loopedTitle3)
                        .foregroundColor(.loopedTextPrimary)
                    
                    // Post example
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("@anonymous")
                                .font(.loopedSubheadMedium)
                                .foregroundColor(.loopedTextSecondary)
                            Spacer()
                            Text("2m")
                                .font(.loopedCaption)
                                .foregroundColor(.loopedTextSecondary)
                        }
                        
                        Text("This is a sample post showing how different font styles work together in a real interface.")
                            .font(.loopedBody)
                            .foregroundColor(.loopedTextPrimary)
                        
                        HStack {
                            Button("Like") {
                                print("Like tapped")
                            }
                            .font(.loopedFootnote)
                            .foregroundColor(.loopedPrimary)
                            
                            Button("Reply") {
                                print("Reply tapped")
                            }
                            .font(.loopedFootnote)
                            .foregroundColor(.loopedPrimary)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color.loopedSurface)
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle("Font System")
    }
}

// MARK: - Font Setup Guide
struct FontSetupGuide: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Font Setup Guide")
                    .font(.loopedTitle2)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("1. Add Font Files")
                        .font(.loopedHeadline)
                    
                    Text("• Add .ttf/.otf files to your project\n• Make sure they're added to your target\n• Add font filenames to Info.plist under 'Fonts provided by application'")
                        .font(.loopedBody)
                    
                    Text("2. Register Fonts")
                        .font(.loopedHeadline)
                    
                    Text("In your App.swift file:")
                        .font(.loopedBody)
                    
                    Text("""
                    @main
                    struct loopedApp: App {
                        init() {
                            LoopedFontLoader.registerFonts()
                        }
                        
                        var body: some Scene {
                            WindowGroup {
                                ContentView()
                            }
                        }
                    }
                    """)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("3. Usage Examples")
                        .font(.loopedHeadline)
                    
                    Text("""
                    Text("Hello World")
                        .font(.loopedBody)
                        
                    Text("Button Label")
                        .font(.loopedButton)
                        
                    Text("Title")
                        .font(.loopedTitle)
                    """)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Setup Guide")
    }
}

#Preview("Font Examples") {
    NavigationView {
        FontExamples()
    }
}

#Preview("Setup Guide") {
    NavigationView {
        FontSetupGuide()
    }
}