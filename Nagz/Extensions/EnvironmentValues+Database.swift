import SwiftUI

private struct DatabaseManagerKey: EnvironmentKey {
    static let defaultValue: DatabaseManager? = nil
}

extension EnvironmentValues {
    var databaseManager: DatabaseManager? {
        get { self[DatabaseManagerKey.self] }
        set { self[DatabaseManagerKey.self] = newValue }
    }
}
