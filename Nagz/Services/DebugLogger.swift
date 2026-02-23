import Foundation
import os

final class DebugLogger: Sendable {
    static let shared = DebugLogger()

    enum Level: String, Sendable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    private let osLogger = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nagz.app", category: "Nagz")
    private let fileURL: URL
    private let maxFileSize: Int = 500_000 // 500KB
    private let queue = DispatchQueue(label: "com.nagz.debuglogger")

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        fileURL = caches.appendingPathComponent("nagz_debug.log")
    }

    func log(_ message: String, level: Level = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(level.rawValue)] \(message)\n"

        switch level {
        case .debug:
            osLogger.debug("\(message, privacy: .public)")
        case .info:
            osLogger.info("\(message, privacy: .public)")
        case .warning:
            osLogger.warning("\(message, privacy: .public)")
        case .error:
            osLogger.error("\(message, privacy: .public)")
        }

        queue.async { [self] in
            self.appendToFile(line)
        }
    }

    func logFileURL() -> URL {
        fileURL
    }

    func logFileData() -> Data? {
        try? Data(contentsOf: fileURL)
    }

    func clearLog() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }

    private func appendToFile(_ line: String) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }

        // Roll if over max size
        if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int, size > maxFileSize {
            // Keep the last half of the file
            if let data = try? Data(contentsOf: fileURL) {
                let halfIndex = data.count / 2
                let trimmed = data.subdata(in: halfIndex..<data.count)
                try? trimmed.write(to: fileURL)
            }
        }

        guard let data = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: fileURL) else { return }
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }
}
