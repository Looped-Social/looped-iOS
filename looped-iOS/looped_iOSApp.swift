//
//  looped_iOSApp.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI
import FirebaseCore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif


class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    #if canImport(GoogleSignIn)
    if let clientID = FirebaseApp.app()?.options.clientID {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
    #endif

    return true
  }
}

@main
struct looped_iOSApp: App {
    init() {
        LoopedFontLoader.registerFonts()
    }
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
