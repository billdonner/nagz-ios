import Foundation

/// A type-safe state machine for async data loading.
/// Eliminates invalid combinations of isLoading/errorMessage/data booleans.
enum LoadState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .success(let v) = self { return v }
        return nil
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    var error: Error? {
        if case .failure(let e) = self { return e }
        return nil
    }
}
