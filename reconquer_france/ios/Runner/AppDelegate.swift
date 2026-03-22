import UIKit
import Flutter
import Firebase
import flutter_background_geolocation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Firebase initialization
        FirebaseApp.configure()

        // Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)

        // Configure background geolocation
        BackgroundGeolocationAppDelegate.shared
            .application(application, didFinishLaunchingWithOptions: launchOptions)

        // Request notification authorization
        UNUserNotificationCenter.current().delegate = self

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Handle background fetch
    override func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }

    // Handle FCM push registration
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // Display notifications when app is in foreground (HUSKER always shows)
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let notifType = userInfo["type"] as? String ?? ""

        if notifType == "husker" {
            // HUSKER: always show with sound and banner even if app is open
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            // Corn and other: show normally
            completionHandler([.banner, .sound, .badge, .list])
        }
    }
}
