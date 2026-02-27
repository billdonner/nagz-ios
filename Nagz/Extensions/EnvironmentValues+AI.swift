import SwiftUI

private struct AIServiceKey: EnvironmentKey {
    static let defaultValue: (any AIService)? = nil
}

extension EnvironmentValues {
    var aiService: (any AIService)? {
        get { self[AIServiceKey.self] }
        set { self[AIServiceKey.self] = newValue }
    }
}
