import UIKit
import Flutter
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // STEP 1: Initialize Firebase FIRST (before anything else)
    FirebaseApp.configure()
    print("🔥 Firebase configured")
    
    // STEP 2: Set up notification center delegate (iOS 10+)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      
      // Request notification permissions
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if granted {
            print("✅ Notification permission granted")
          } else {
            print("❌ Notification permission denied")
            if let error = error {
              print("❌ Error: \(error.localizedDescription)")
            }
          }
        }
      )
    } else {
      // iOS 9 and below
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    // STEP 3: Register for remote notifications (CRITICAL for APNS token)
    application.registerForRemoteNotifications()
    print("📲 Registered for remote notifications")
    
    // STEP 4: Set Firebase Messaging delegate
    Messaging.messaging().delegate = self
    print("✅ Firebase Messaging delegate set")
    
    // STEP 5: Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // ============================================================================
  // MARK: - APNs Token Handling (CRITICAL for iOS Push Notifications)
  // ============================================================================
  
  /// Called when APNs successfully registers the device
  /// This is where we get the APNs token and pass it to Firebase
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("✅ APNs device token received successfully")
    
    // Convert device token to hex string for logging
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("✅ APNs Token: \(token)")
    
    // CRITICAL: Pass APNs token to Firebase Messaging
    // This allows Firebase to generate an FCM token
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNs token set in Firebase Messaging")
  }
  
  /// Called when APNs registration fails
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs registration FAILED")
    print("❌ Error: \(error.localizedDescription)")
    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("⚠️  APNS REGISTRATION FAILURE")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
    print("Common causes:")
    print("1. Push Notifications capability not enabled in Xcode")
    print("2. Running on iOS Simulator (use real device)")
    print("3. Network connectivity issues")
    print("4. Free Apple Developer account limitations")
    print("5. Invalid provisioning profile")
    print("")
    print("Solutions:")
    print("→ Xcode: Runner target → Signing & Capabilities")
    print("→ Add 'Push Notifications' capability")
    print("→ Test on real iOS device (not simulator)")
    print("→ Consider using paid Apple Developer account")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("")
  }
  
  // ============================================================================
  // MARK: - Notification Handling (Foreground, Background, Tap)
  // ============================================================================
  
  /// Handle notification when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    
    print("📬 Notification received in FOREGROUND")
    print("📋 Title: \(notification.request.content.title)")
    print("📋 Body: \(notification.request.content.body)")
    
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .badge, .sound]])
    } else {
      completionHandler([[.alert, .badge, .sound]])
    }
  }
  
  /// Handle notification tap (when user taps notification)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    
    print("👆 Notification TAPPED by user")
    print("📋 Data: \(userInfo)")
    
    // TODO: Handle navigation based on notification type
    // You can extract notification_type or other data from userInfo
    // and navigate to appropriate screen
    
    completionHandler()
  }
}

// ============================================================================
// MARK: - Firebase Messaging Delegate
// ============================================================================

extension AppDelegate: MessagingDelegate {
  
  /// Called when FCM token is available or refreshed
  /// This is the token you send to your backend server
  func messaging(
    _ messaging: Messaging,
    didReceiveRegistrationToken fcmToken: String?
  ) {
    guard let fcmToken = fcmToken else {
      print("⚠️ FCM token is nil")
      return
    }
    
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ FCM TOKEN RECEIVED")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("Token: \(fcmToken)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    // Create data dictionary for Flutter side
    let dataDict: [String: String] = ["token": fcmToken]
    
    // Post notification so Flutter can receive the token if needed
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
  
  /// Called when Firebase Messaging receives a remote message
  /// while the app is in foreground
  func messaging(
    _ messaging: Messaging,
    didReceive remoteMessage: MessagingDelegate
  ) {
    print("📨 Remote message received via Firebase Messaging")
  }
}