//
//  looped_iOSApp.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI
import FirebaseCore
import UserNotifications
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    #if canImport(GoogleSignIn)
    if let clientID = FirebaseApp.app()?.options.clientID {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
    #endif

    configureNotifications()
    return true
  }

  private func configureNotifications() {
      let center = UNUserNotificationCenter.current()
      center.delegate = self
      center.getNotificationSettings { settings in
          let authorized: Bool
          switch settings.authorizationStatus {
          case .authorized, .provisional, .ephemeral:
              authorized = true
          default:
              authorized = false
          }
          guard authorized else { return }
          DispatchQueue.main.async {
              UIApplication.shared.registerForRemoteNotifications()
          }
      }
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      let token = deviceToken.map { String(format: "%02x", $0) }.joined()
      NotificationDeviceRegistrar.shared.storeDeviceToken(token)
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("APNs registration failed: \(error.localizedDescription)")
  }

  func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
      completionHandler([.badge, .sound, .banner])
  }

  func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
  ) {
      handleDeeplink(userInfo: response.notification.request.content.userInfo)
      completionHandler()
  }

  private func handleDeeplink(userInfo: [AnyHashable: Any]) {
      guard let deeplink = userInfo["deeplink"] as? String,
            let url = URL(string: deeplink) else { return }
      DispatchQueue.main.async {
          UIApplication.shared.open(url)
      }
  }
}

@main
struct looped_iOSApp: App {
    init() {
        LoopedFontLoader.registerFonts()
    }
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppearanceMode.from(rawValue: appearanceMode).colorScheme)
        }
    }
}
