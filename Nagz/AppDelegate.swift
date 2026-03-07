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
        // Cold-launch from notification tap: pushService isn't wired yet so
        // save the nag_id directly to UserDefaults for restorePendingNag() to pick up.
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let nagIdString = userInfo["nag_id"] as? String,
           let _ = UUID(uuidString: nagIdString) {
            let targetUserId = userInfo["target_user_id"] as? String
            let currentUserId = UserDefaults.standard.string(forKey: "nagz_user_id")
            let isForCurrentUser = targetUserId == nil || targetUserId == currentUserId
            if isForCurrentUser {
                UserDefaults.standard.set(nagIdString, forKey: "nagz_pending_nag_id")
                print("🔔 cold launch nag_id=\(nagIdString) saved to UserDefaults")
            }
        }

        let delegate = NotificationDelegate(appDelegate: self)
        notificationDelegate = delegate
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        // Register "nag" category with a View action — makes banners persistent
        let viewAction = UNNotificationAction(
            identifier: "VIEW_NAG",
            title: "View",
            options: [.foreground]
        )
        let nagCategory = UNNotificationCategory(
            identifier: "NAG",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([nagCategory])
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
        let userInfo = response.notification.request.content.userInfo
        let targetUserId = userInfo["target_user_id"] as? String
        let nagIdString = userInfo["nag_id"] as? String
        print("🔔 didReceive — nag_id=\(nagIdString ?? "nil") target=\(targetUserId ?? "nil") keys=\(userInfo.keys.map{"\($0)"})")
        let isForCurrent = await Self.isForCurrentUser(targetUserId: targetUserId)
        print("🔔 isForCurrentUser=\(isForCurrent)")
        guard isForCurrent else { return }

        guard let nagIdString, let nagId = UUID(uuidString: nagIdString) else {
            print("🔔 failed to parse nag UUID from: \(nagIdString ?? "nil")")
            return
        }
        print("🔔 calling setPendingNag(\(nagId))")
        await MainActor.run {
            appDelegate?.pushService?.setPendingNag(nagId)
            print("🔔 setPendingNag done, pushService=\(String(describing: appDelegate?.pushService))")
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
        return targetUserId.caseInsensitiveCompare(currentUserId) == .orderedSame
    }
}
