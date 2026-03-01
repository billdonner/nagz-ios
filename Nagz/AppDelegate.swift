import UIKit
import UserNotifications

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {
    var pushService: PushNotificationService?
    private var notificationDelegate: NotificationDelegate?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let delegate = NotificationDelegate(appDelegate: self)
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        pushService?.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        DebugLogger.shared.log("Failed to register for remote notifications: \(error.localizedDescription)", level: .error)
    }
}

@MainActor
private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let nagIdString = response.notification.request.content.userInfo["nag_id"] as? String
        await MainActor.run {
            if let nagIdString, let nagId = UUID(uuidString: nagIdString) {
                self.appDelegate?.pushService?.handleNotificationTap(userInfo: ["nag_id": nagId.uuidString])
            }
        }
    }
}
