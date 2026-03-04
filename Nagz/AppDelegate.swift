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
        // Extract values in nonisolated context to avoid Sendable issues
        let targetUserId = notification.request.content.userInfo["target_user_id"] as? String
        let isForCurrent = await Self.isForCurrentUser(targetUserId: targetUserId)
        guard isForCurrent else { return [] }
        return [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let targetUserId = response.notification.request.content.userInfo["target_user_id"] as? String
        let nagIdString = response.notification.request.content.userInfo["nag_id"] as? String
        let isForCurrent = await Self.isForCurrentUser(targetUserId: targetUserId)
        guard isForCurrent else { return }

        if let nagIdString, let nagId = UUID(uuidString: nagIdString) {
            UserDefaults.standard.set(nagId.uuidString, forKey: "nagz_pending_nag_id")
        }
    }

    /// Check if the notification is intended for the currently logged-in user.
    @MainActor
    private static func isForCurrentUser(targetUserId: String?) -> Bool {
        guard let targetUserId else {
            // No target_user_id in payload — allow (backwards compatibility)
            return true
        }
        guard let currentUserId = UserDefaults.standard.string(forKey: "nagz_user_id") else {
            return false
        }
        return targetUserId == currentUserId
    }
}
