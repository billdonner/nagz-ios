import Foundation
import UIKit
import UserNotifications
import Observation

@Observable
@MainActor
final class PushNotificationService: NSObject {
    private(set) var pendingNagId: UUID?
    private var apiClient: APIClient?

    func configure(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func handleDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        #if targetEnvironment(macCatalyst)
        let platform = DevicePlatform.macos
        #elseif os(iOS)
        let platform: DevicePlatform = UIDevice.current.userInterfaceIdiom == .pad ? .ipados : .ios
        #endif

        Task {
            guard let apiClient else { return }
            let _: DeviceTokenResponse = try await apiClient.request(
                .registerDevice(platform: platform, token: token)
            )
        }
    }

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        if let nagIdString = userInfo["nag_id"] as? String,
           let nagId = UUID(uuidString: nagIdString) {
            pendingNagId = nagId
        }
    }

    func clearPendingNag() {
        pendingNagId = nil
    }
}
