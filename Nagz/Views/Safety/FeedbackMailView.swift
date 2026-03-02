import SwiftUI
import MessageUI
import UIKit

@MainActor
enum DeviceDiagnostics {
    static var summary: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let device = unameMachine
        let osVersion = UIDevice.current.systemVersion
        let locale = Locale.current.identifier
        let apiVersion = Constants.Version.clientAPIVersion
        return """
        App Version: \(version) (\(build))
        API Version: \(apiVersion)
        Device: \(device)
        iOS: \(osVersion)
        Locale: \(locale)
        """
    }

    private static var unameMachine: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? UIDevice.current.model
            }
        }
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let attachmentData: Data?
    let attachmentFilename: String
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        if let data = attachmentData {
            vc.addAttachmentData(data, mimeType: "text/plain", fileName: attachmentFilename)
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        @MainActor
        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
        }
    }
}
