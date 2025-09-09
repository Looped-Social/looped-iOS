//
//  looped_iOSApp.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI

@main
struct looped_iOSApp: App {
    init() {
        LoopedFontLoader.registerFonts()
        // Debug: Print available fonts
        LoopedFontLoader.printAvailableFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
