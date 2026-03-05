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
        DebugLogger.shared.log("📱 AppDelegate: didFinishLaunchingWithOptions", level: .info)
        if let launchNotif = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            DebugLogger.shared.log("📱 AppDelegate: launched from notification — \(launchNotif)", level: .info)
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        DebugLogger.shared.log("📱 AppDelegate: registered device token \(token.prefix(12))…", level: .info)
        pushService?.handleDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        DebugLogger.shared.log("📱 AppDelegate: FAILED to register for remote notifications: \(error.localizedDescription)", level: .error)
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
        let userInfo = notification.request.content.userInfo
        let targetUserId = userInfo["target_user_id"] as? String
        let nagId = userInfo["nag_id"] as? String
        let eventType = userInfo["event_type"] as? String
        let title = notification.request.content.title
        DebugLogger.shared.log("📬 willPresent: title='\(title)' event=\(eventType ?? "?") nag=\(nagId ?? "nil") target=\(targetUserId ?? "any")", level: .info)

        let isForCurrent = await Self.isForCurrentUser(targetUserId: targetUserId)
        if !isForCurrent {
            DebugLogger.shared.log("📬 willPresent: SUPPRESSED — not for current user", level: .info)
            return []
        }
        DebugLogger.shared.log("📬 willPresent: SHOWING banner+badge+sound", level: .info)
        return [.banner, .badge, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let targetUserId = userInfo["target_user_id"] as? String
        let nagIdString = userInfo["nag_id"] as? String
        let actionId = response.actionIdentifier
        let allKeys = userInfo.keys.map { "\($0)" }.sorted().joined(separator: ", ")
        DebugLogger.shared.log("👆 didReceive: action='\(actionId)' nag=\(nagIdString ?? "nil") target=\(targetUserId ?? "any") keys=[\(allKeys)]", level: .info)

        let isForCurrent = await Self.isForCurrentUser(targetUserId: targetUserId)
        if !isForCurrent {
            DebugLogger.shared.log("👆 didReceive: IGNORED — not for current user", level: .info)
            return
        }

        guard let nagIdString else {
            DebugLogger.shared.log("👆 didReceive: NO nag_id in payload — cannot navigate", level: .warning)
            return
        }
        guard let nagId = UUID(uuidString: nagIdString) else {
            DebugLogger.shared.log("👆 didReceive: nag_id '\(nagIdString)' is not a valid UUID", level: .warning)
            return
        }

        DebugLogger.shared.log("👆 didReceive: calling setPendingNag(\(nagId))", level: .info)
        await MainActor.run {
            appDelegate?.pushService?.setPendingNag(nagId)
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
            DebugLogger.shared.log("⚠️ isForCurrentUser: no nagz_user_id in UserDefaults", level: .warning)
            return false
        }
        let match = targetUserId == currentUserId
        if !match {
            DebugLogger.shared.log("⚠️ isForCurrentUser: mismatch — target=\(targetUserId.prefix(8)) current=\(currentUserId.prefix(8))", level: .info)
        }
        return match
    }
}
