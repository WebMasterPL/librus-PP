import UIKit
import UserNotifications

/// The app's only reason to have an app delegate: to be the notification-center
/// delegate. Without one, iOS silently drops any notification that fires while the
/// app is in the foreground — including the "send test notification" button in
/// Settings, which fires a few seconds out while the user is still on the screen.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        BackgroundRefresh.register()
        return true
    }

    /// Show grade / timetable / message alerts as a banner even when the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
