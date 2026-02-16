import Foundation

enum AppEnvironment {
    case development
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    var baseURL: URL {
        switch self {
        case .development:
            URL(string: "http://localhost:8001/api/v1")!
        case .production:
            // TODO: Replace with production URL
            URL(string: "https://api.nagz.app/api/v1")!
        }
    }
}
