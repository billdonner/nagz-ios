import Foundation
import Observation

@Observable
@MainActor
final class NagDetailViewModel {
    var loadState: LoadState<NagResponse> = .idle
    var escalation: EscalationResponse?
    var excuses: [ExcuseResponse] = []
    var isUpdating = false
    var isRecomputing = false
    var errorMessage: String?   // mutation errors only

    /// Convenience accessor; setting it updates loadState.
    var nag: NagResponse? {
        get { loadState.value }
        set { if let v = newValue { loadState = .success(v) } }
    }

    private let apiClient: APIClient
    private let nagId: UUID

    init(apiClient: APIClient, nagId: UUID) {
        self.apiClient = apiClient
        self.nagId = nagId
    }

    func load() async {
        guard !loadState.isLoading else { return }
        if loadState.value == nil { loadState = .loading }

        do {
            let loadedNag: NagResponse = try await apiClient.request(.getNag(id: nagId))
            loadState = .success(loadedNag)
        } catch {
            if loadState.value == nil {
                loadState = .failure(error)
            }
            return
        }

        // Escalation may not exist yet, that's OK
        do {
            let loadedEscalation: EscalationResponse = try await apiClient.request(.getEscalation(nagId: nagId))
            escalation = loadedEscalation
        } catch {
            // Ignore escalation errors
        }

        // Load excuses
        do {
            let response: PaginatedResponse<ExcuseResponse> = try await apiClient.request(.listExcuses(nagId: nagId))
            excuses = response.items
        } catch {
            // Excuses might not exist
        }
    }

    func markComplete(note: String? = nil) async {
        isUpdating = true
        errorMessage = nil
        do {
            let updated: NagResponse = try await apiClient.request(
                .updateNagStatus(nagId: nagId, status: .completed, note: note)
            )
            nag = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func submitExcuse(text: String) async {
        isUpdating = true
        errorMessage = nil
        do {
            let _: ExcuseResponse = try await apiClient.request(
                .submitExcuse(nagId: nagId, text: text)
            )
            // Reload excuses
            do {
                let response: PaginatedResponse<ExcuseResponse> = try await apiClient.request(.listExcuses(nagId: nagId))
                excuses = response.items
            } catch {}
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func snooze(minutes: Int) async {
        guard let nag else { return }
        isUpdating = true
        errorMessage = nil
        let base = max(nag.dueAt, Date())
        let newDue = base.addingTimeInterval(Double(minutes) * 60)
        let update = NagUpdate(dueAt: newDue)
        do {
            let updated: NagResponse = try await apiClient.request(
                .updateNag(nagId: nagId, update: update)
            )
            self.nag = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func commitTime(date: Date) async {
        isUpdating = true
        errorMessage = nil
        let update = NagUpdate(committedAt: date)
        do {
            let updated: NagResponse = try await apiClient.request(
                .updateNag(nagId: nagId, update: update)
            )
            self.nag = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func withdraw() async {
        isUpdating = true
        errorMessage = nil
        do {
            let updated: NagResponse = try await apiClient.request(.withdrawNag(nagId: nagId))
            nag = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func dismiss() async {
        isUpdating = true
        errorMessage = nil
        do {
            let updated: NagResponse = try await apiClient.request(.dismissNag(nagId: nagId))
            nag = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func undismiss() async {
        isUpdating = true
        errorMessage = nil
        do {
            let updated: NagResponse = try await apiClient.request(.undismissNag(nagId: nagId))
            nag = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    func recomputeEscalation() async {
        isRecomputing = true
        errorMessage = nil
        do {
            let updated: EscalationResponse = try await apiClient.request(
                .recomputeEscalation(nagId: nagId)
            )
            escalation = updated
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isRecomputing = false
    }
}
