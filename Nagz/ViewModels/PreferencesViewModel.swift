import Foundation
import Observation

@Observable
@MainActor
final class PreferencesViewModel {
    var gamificationEnabled = false
    var quietHoursEnabled = false
    var quietHoursStart = "22:00"
    var quietHoursEnd = "07:00"
    var notificationFrequency = "always"
    var deliveryChannel = "push"
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    private let apiClient: APIClient
    private let familyId: UUID

    init(apiClient: APIClient, familyId: UUID) {
        self.apiClient = apiClient
        self.familyId = familyId
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let response: PreferenceResponse = try await apiClient.request(
                .getPreferences(familyId: familyId)
            )
            applyPrefs(response.prefsJson)
        } catch {
            // Preferences may not exist yet — use defaults
        }
        isLoading = false
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        var prefs: [String: AnyCodableValue] = [
            "gamification_enabled": .bool(gamificationEnabled),
            "quiet_hours_enabled": .bool(quietHoursEnabled),
        ]
        if quietHoursEnabled {
            prefs["quiet_hours_start"] = .string(quietHoursStart)
            prefs["quiet_hours_end"] = .string(quietHoursEnd)
        }
        prefs["notification_frequency"] = .string(notificationFrequency)
        prefs["delivery_channel"] = .string(deliveryChannel)
        do {
            let _: PreferenceResponse = try await apiClient.request(
                .updatePreferences(familyId: familyId, prefs: prefs)
            )
            didSave = true
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func applyPrefs(_ prefs: [String: AnyCodableValue]) {
        gamificationEnabled = prefs["gamification_enabled"]?.boolValue ?? false
        quietHoursEnabled = prefs["quiet_hours_enabled"]?.boolValue ?? false
        quietHoursStart = prefs["quiet_hours_start"]?.stringValue ?? "22:00"
        quietHoursEnd = prefs["quiet_hours_end"]?.stringValue ?? "07:00"
        notificationFrequency = prefs["notification_frequency"]?.stringValue ?? "always"
        deliveryChannel = prefs["delivery_channel"]?.stringValue ?? "push"
    }
}
