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
            URL(string: "http://127.0.0.1:8001/api/v1")!
        case .production:
            URL(string: "https://api.nagz.app/api/v1")!
        }
    }
}
