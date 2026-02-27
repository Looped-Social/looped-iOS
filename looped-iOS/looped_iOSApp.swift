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
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  private let allowlistedUniversalHost = "mylooped.app"

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
      DeepLinkRouter.shared.markDidBecomeActive()
      Task {
          await TelemetryManager.shared.appDidBecomeActive()
      }
      DispatchQueue.global(qos: .utility).async {
          CacheHousekeeper.runIfNeeded()
      }
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
      Task {
          await TelemetryManager.shared.appDidEnterBackground()
      }
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

      return DeepLinkRouter.shared.handleIncomingURL(url)
  }

  func application(
      _ application: UIApplication,
      continue userActivity: NSUserActivity,
      restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
      DeepLinkRouter.shared.handleUserActivity(userActivity)
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
      completionHandler(notificationPresentationOptions(userInfo: notification.request.content.userInfo))
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
      let type = (userInfo["type"] as? String)?
          .trimmingCharacters(in: .whitespacesAndNewlines)
          .lowercased()
      let primaryURL = allowlistedDeeplinkURL(userInfo["deeplink"])
      let fallbackURL: URL? = {
          guard type == "trending_today" else { return nil }
          return allowlistedDeeplinkURL(userInfo["fallback_deeplink"])
      }()

      DispatchQueue.main.async {
          if let primaryURL, DeepLinkRouter.shared.handleIncomingURL(primaryURL, fallbackURL: fallbackURL) {
              return
          }
          if let fallbackURL, DeepLinkRouter.shared.handleIncomingURL(fallbackURL) {
              return
          }
          _ = DeepLinkRouter.shared.handleIncomingURL(URL(string: "looped://home")!)
      }
  }

  private func allowlistedDeeplinkURL(_ rawValue: Any?) -> URL? {
      guard let raw = rawValue as? String else { return nil }
      guard let url = URL(string: raw) else { return nil }
      let scheme = (url.scheme ?? "").lowercased()
      if scheme == "looped" {
          return url
      }
      if scheme == "https", (url.host ?? "").lowercased() == allowlistedUniversalHost {
          return url
      }
      return nil
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

      NotificationCenter.default.post(
          name: .notificationMarkedRead,
          object: nil,
          userInfo: [LoopedNotificationUserInfoKey.notificationId: notificationId]
      )

      Task {
          try? await NotificationService().markRead(notificationId: notificationId)
      }
  }

  private func notificationPresentationOptions(userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
      guard let deeplink = userInfo["deeplink"] as? String,
            let url = URL(string: deeplink),
            url.scheme == "looped"
      else {
          return [.badge, .sound, .banner]
      }

      let host = (url.host ?? "").lowercased()
      let pathComponents = url.pathComponents.filter { $0 != "/" }
      let idValue = pathComponents.first.flatMap(Int.init)

      switch host {
      case "conversations":
          if let idValue, MutedChatStore.shared.isConversationMuted(idValue) {
              return [.badge]
          }
      case "channels":
          if let idValue, MutedChatStore.shared.isChannelMuted(idValue) {
              return [.badge]
          }
      default:
          break
      }

      return [.badge, .sound, .banner]
  }
}

@main
struct looped_iOSApp: App {
    init() {
        CacheHousekeeper.configureCacheLimits()
        #if canImport(AppIntents)
        LoopedAppShortcuts.updateAppShortcutParameters()
        #endif
        DispatchQueue.global(qos: .utility).async {
            CacheHousekeeper.runIfNeeded()
        }
    }
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkRouter)
                .preferredColorScheme(AppearanceMode.from(rawValue: appearanceMode).colorScheme)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    _ = deepLinkRouter.handleUserActivity(userActivity)
                }
                #if canImport(CoreSpotlight)
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    _ = deepLinkRouter.handleUserActivity(userActivity)
                }
                #endif
                .onOpenURL { url in
                    #if canImport(FirebaseAuth)
                    if Auth.auth().canHandle(url) {
                        return
                    }
                    #endif
                    _ = deepLinkRouter.handleIncomingURL(url)
                }
        }
    }
}
