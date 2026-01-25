//
//  looped_iOSApp.swift
//  looped-iOS
//
//  Created by William Millen on 9/5/25.
//

import SwiftUI
import Foundation
import FirebaseCore
import UserNotifications
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
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

  func applicationDidBecomeActive(_ application: UIApplication) {
      DispatchQueue.global(qos: .utility).async {
          CacheHousekeeper.runIfNeeded()
      }
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
      DispatchQueue.global(qos: .utility).async {
          CacheHousekeeper.runIfNeeded()
      }
  }

  private func configureNotifications() {
      let center = UNUserNotificationCenter.current()
      center.delegate = self
      DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
      }
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      let token = deviceToken.map { String(format: "%02x", $0) }.joined()
      NotificationDeviceRegistrar.shared.storeDeviceToken(token)

      #if canImport(FirebaseAuth)
      let tokenType: AuthAPNSTokenType = {
          #if DEBUG
          return .sandbox
          #else
          return .prod
          #endif
      }()
      Auth.auth().setAPNSToken(deviceToken, type: tokenType)
      #endif
  }

  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
  }

  func application(
      _ app: UIApplication,
      open url: URL,
      options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
      #if canImport(FirebaseAuth)
      if Auth.auth().canHandle(url) {
          return true
      }
      #endif

      #if canImport(GoogleSignIn)
      if GIDSignIn.sharedInstance.handle(url) {
          return true
      }
      #endif

      return false
  }

  func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable: Any],
      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
      #if canImport(FirebaseAuth)
      if Auth.auth().canHandleNotification(userInfo) {
          completionHandler(.noData)
          return
      }
      #endif
      completionHandler(.noData)
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
      markNotificationRead(userInfo: userInfo)
      guard let deeplink = userInfo["deeplink"] as? String,
            let url = URL(string: deeplink) else { return }
      DispatchQueue.main.async {
          UIApplication.shared.open(url)
      }
  }

  private func markNotificationRead(userInfo: [AnyHashable: Any]) {
      let rawValue = userInfo["notification_id"]
      let notificationId: Int? = {
          if let intValue = rawValue as? Int {
              return intValue
          }
          if let stringValue = rawValue as? String {
              return Int(stringValue)
          }
          return nil
      }()
      guard let notificationId else { return }

      Task {
          try? await NotificationService().markRead(notificationId: notificationId)
      }
  }
}

@main
struct looped_iOSApp: App {
    init() {
        LoopedFontLoader.registerFonts()
        CacheHousekeeper.configureCacheLimits()
        DispatchQueue.global(qos: .utility).async {
            CacheHousekeeper.runIfNeeded()
        }
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
