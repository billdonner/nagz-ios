import XCTest
@testable import Nagz

// MARK: - NagFilter Tests

final class NagFilterTests: XCTestCase {

    func testOpenFilterReturnsOpenStatus() {
        XCTAssertEqual(NagFilter.open.nagStatus, .open)
    }

    func testCompletedFilterReturnsCompletedStatus() {
        XCTAssertEqual(NagFilter.completed.nagStatus, .completed)
    }

    func testAllFilterReturnsNilStatus() {
        XCTAssertNil(NagFilter.all.nagStatus)
    }

    func testNagFilterRawValues() {
        XCTAssertEqual(NagFilter.open.rawValue, "Open")
        XCTAssertEqual(NagFilter.completed.rawValue, "Completed")
        XCTAssertEqual(NagFilter.all.rawValue, "All")
    }

    func testNagFilterCaseIterableHasFourCases() {
        XCTAssertEqual(NagFilter.allCases.count, 4)
    }
}

// MARK: - FamilyRole Tests

final class FamilyRoleTests: XCTestCase {

    func testGuardianCanCreateNags() {
        XCTAssertTrue(FamilyRole.guardian.canCreateNags)
    }

    func testParticipantCanCreateNags() {
        XCTAssertTrue(FamilyRole.participant.canCreateNags)
    }

    func testChildCannotCreateNags() {
        XCTAssertFalse(FamilyRole.child.canCreateNags)
    }

    func testOnlyGuardianCanViewAllNags() {
        XCTAssertTrue(FamilyRole.guardian.canViewAllNags)
        XCTAssertFalse(FamilyRole.participant.canViewAllNags)
        XCTAssertFalse(FamilyRole.child.canViewAllNags)
    }

    func testOnlyGuardianIsAdmin() {
        XCTAssertTrue(FamilyRole.guardian.isAdmin)
        XCTAssertFalse(FamilyRole.participant.isAdmin)
        XCTAssertFalse(FamilyRole.child.isAdmin)
    }

    func testFamilyRoleRawValues() {
        XCTAssertEqual(FamilyRole.guardian.rawValue, "guardian")
        XCTAssertEqual(FamilyRole.participant.rawValue, "participant")
        XCTAssertEqual(FamilyRole.child.rawValue, "child")
    }
}

// MARK: - NagCategory Tests

final class NagCategoryTests: XCTestCase {

    func testCategoryDisplayNames() {
        XCTAssertEqual(NagCategory.chores.displayName, "Chores")
        XCTAssertEqual(NagCategory.meds.displayName, "Meds")
        XCTAssertEqual(NagCategory.homework.displayName, "Homework")
        XCTAssertEqual(NagCategory.appointments.displayName, "Appointments")
        XCTAssertEqual(NagCategory.other.displayName, "Other")
    }

    func testCategoryIconNames() {
        XCTAssertEqual(NagCategory.chores.iconName, "house.fill")
        XCTAssertEqual(NagCategory.meds.iconName, "pill.fill")
        XCTAssertEqual(NagCategory.homework.iconName, "book.fill")
        XCTAssertEqual(NagCategory.appointments.iconName, "calendar")
        XCTAssertEqual(NagCategory.other.iconName, "ellipsis.circle.fill")
    }

    func testCategoryHasFiveCases() {
        XCTAssertEqual(NagCategory.allCases.count, 5)
    }
}

// MARK: - DoneDefinition Tests

final class DoneDefinitionTests: XCTestCase {

    func testDoneDefinitionRawValues() {
        XCTAssertEqual(DoneDefinition.ackOnly.rawValue, "ack_only")
        XCTAssertEqual(DoneDefinition.binaryCheck.rawValue, "binary_check")
        XCTAssertEqual(DoneDefinition.binaryWithNote.rawValue, "binary_with_note")
    }

    func testDoneDefinitionDisplayNames() {
        XCTAssertEqual(DoneDefinition.ackOnly.displayName, "Acknowledge")
        XCTAssertEqual(DoneDefinition.binaryCheck.displayName, "Check Off")
        XCTAssertEqual(DoneDefinition.binaryWithNote.displayName, "Check Off + Note")
    }
}

// MARK: - NagStatus Tests

final class NagStatusTests: XCTestCase {

    func testNagStatusRawValues() {
        XCTAssertEqual(NagStatus.open.rawValue, "open")
        XCTAssertEqual(NagStatus.completed.rawValue, "completed")
        XCTAssertEqual(NagStatus.missed.rawValue, "missed")
        XCTAssertEqual(NagStatus.cancelledRelationshipChange.rawValue, "cancelled_relationship_change")
    }
}

// MARK: - EscalationPhase Tests

final class EscalationPhaseTests: XCTestCase {

    func testEscalationPhaseDisplayNames() {
        XCTAssertEqual(EscalationPhase.phase0Initial.displayName, "Created")
        XCTAssertEqual(EscalationPhase.phase1DueSoon.displayName, "Due Soon")
        XCTAssertEqual(EscalationPhase.phase2OverdueSoft.displayName, "Overdue")
        XCTAssertEqual(EscalationPhase.phase3OverdueBoundedPushback.displayName, "Escalated")
        XCTAssertEqual(EscalationPhase.phase4GuardianReview.displayName, "Guardian Review")
    }

    func testEscalationPhaseComparable() {
        XCTAssertTrue(EscalationPhase.phase0Initial < EscalationPhase.phase1DueSoon)
        XCTAssertTrue(EscalationPhase.phase1DueSoon < EscalationPhase.phase2OverdueSoft)
        XCTAssertTrue(EscalationPhase.phase2OverdueSoft < EscalationPhase.phase3OverdueBoundedPushback)
        XCTAssertTrue(EscalationPhase.phase3OverdueBoundedPushback < EscalationPhase.phase4GuardianReview)
    }

    func testEscalationPhaseNotLessThanItself() {
        XCTAssertFalse(EscalationPhase.phase0Initial < EscalationPhase.phase0Initial)
    }

    func testEscalationPhaseSorting() {
        let phases: [EscalationPhase] = [
            .phase4GuardianReview,
            .phase0Initial,
            .phase2OverdueSoft,
            .phase1DueSoon,
            .phase3OverdueBoundedPushback,
        ]
        let sorted = phases.sorted()
        XCTAssertEqual(sorted, [
            .phase0Initial,
            .phase1DueSoon,
            .phase2OverdueSoft,
            .phase3OverdueBoundedPushback,
            .phase4GuardianReview,
        ])
    }
}

// MARK: - ConsentType Tests

final class ConsentTypeTests: XCTestCase {

    func testConsentTypeDisplayNames() {
        XCTAssertEqual(ConsentType.childAccountCreation.displayName, "Child Account Creation")
        XCTAssertEqual(ConsentType.smsOptIn.displayName, "SMS Notifications")
        XCTAssertEqual(ConsentType.aiMediation.displayName, "AI Mediation")
        XCTAssertEqual(ConsentType.gamificationParticipation.displayName, "Gamification")
    }

    func testConsentTypeDescriptions() {
        XCTAssertTrue(ConsentType.childAccountCreation.description.contains("child"))
        XCTAssertTrue(ConsentType.smsOptIn.description.contains("SMS"))
        XCTAssertTrue(ConsentType.aiMediation.description.contains("AI"))
        XCTAssertTrue(ConsentType.gamificationParticipation.description.contains("points"))
    }

    func testConsentTypeHasFourCases() {
        XCTAssertEqual(ConsentType.allCases.count, 4)
    }
}

// MARK: - IncentiveApprovalMode Tests

final class IncentiveApprovalModeTests: XCTestCase {

    func testApprovalModeRawValues() {
        XCTAssertEqual(IncentiveApprovalMode.auto.rawValue, "auto")
        XCTAssertEqual(IncentiveApprovalMode.guardianConfirmed.rawValue, "guardian_confirmed")
    }

    func testApprovalModeDisplayNames() {
        XCTAssertEqual(IncentiveApprovalMode.auto.displayName, "Automatic")
        XCTAssertEqual(IncentiveApprovalMode.guardianConfirmed.displayName, "Guardian Confirmed")
    }
}

// MARK: - AnyCodableValue Tests

final class AnyCodableValueTests: XCTestCase {

    func testBoolValueExtraction() {
        let val = AnyCodableValue.bool(true)
        XCTAssertEqual(val.boolValue, true)
        XCTAssertNil(val.stringValue)
    }

    func testStringValueExtraction() {
        let val = AnyCodableValue.string("hello")
        XCTAssertEqual(val.stringValue, "hello")
        XCTAssertNil(val.boolValue)
    }

    func testNullValueExtraction() {
        let val = AnyCodableValue.null
        XCTAssertNil(val.boolValue)
        XCTAssertNil(val.stringValue)
    }

    func testBoolValueEncodeDecode() throws {
        let original = AnyCodableValue.bool(false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testStringValueEncodeDecode() throws {
        let original = AnyCodableValue.string("test")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testIntValueEncodeDecode() throws {
        let original = AnyCodableValue.int(42)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDoubleValueEncodeDecode() throws {
        let original = AnyCodableValue.double(3.14)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnyCodableValue.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testEquality() {
        XCTAssertEqual(AnyCodableValue.bool(true), AnyCodableValue.bool(true))
        XCTAssertNotEqual(AnyCodableValue.bool(true), AnyCodableValue.bool(false))
        XCTAssertNotEqual(AnyCodableValue.bool(true), AnyCodableValue.string("true"))
    }
}

// MARK: - APIError Tests

final class APIErrorTests: XCTestCase {

    func testUnauthorizedDescription() {
        let error = APIError.unauthorized
        XCTAssertEqual(error.errorDescription, "Session expired. Please log in again.")
    }

    func testForbiddenDescription() {
        let error = APIError.forbidden("Only the nag recipient can perform this action")
        XCTAssertEqual(error.errorDescription, "Only the nag recipient can perform this action")
    }

    func testNotFoundDescription() {
        let error = APIError.notFound
        XCTAssertEqual(error.errorDescription, "The requested resource was not found.")
    }

    func testRateLimitedDescription() {
        let error = APIError.rateLimited
        XCTAssertEqual(error.errorDescription, "Too many requests. Please wait a moment and try again.")
    }

    func testValidationErrorDescription() {
        let error = APIError.validationError("Email is required")
        XCTAssertEqual(error.errorDescription, "Email is required")
    }

    func testServerErrorDescription() {
        let error = APIError.serverError("Internal server error")
        XCTAssertEqual(error.errorDescription, "Server error: Internal server error")
    }

    func testInvalidURLDescription() {
        let error = APIError.invalidURL
        XCTAssertEqual(error.errorDescription, "Invalid URL")
    }

    func testUnknownErrorDescription() {
        let error = APIError.unknown(418, "I'm a teapot")
        XCTAssertEqual(error.errorDescription, "Error 418: I'm a teapot")
    }

    func testNetworkErrorIsRetryable() {
        let urlError = URLError(.notConnectedToInternet)
        XCTAssertTrue(APIError.networkError(urlError).isRetryable)
    }

    func testServerErrorIsRetryable() {
        XCTAssertTrue(APIError.serverError("error").isRetryable)
    }

    func testRateLimitedIsRetryable() {
        XCTAssertTrue(APIError.rateLimited.isRetryable)
    }

    func testUnauthorizedIsNotRetryable() {
        XCTAssertFalse(APIError.unauthorized.isRetryable)
    }

    func testNotFoundIsNotRetryable() {
        XCTAssertFalse(APIError.notFound.isRetryable)
    }

    func testForbiddenIsNotRetryable() {
        XCTAssertFalse(APIError.forbidden("denied").isRetryable)
    }

    func testValidationErrorIsNotRetryable() {
        XCTAssertFalse(APIError.validationError("bad").isRetryable)
    }

    func testNetworkErrorNotConnectedDescription() {
        let urlError = URLError(.notConnectedToInternet)
        let error = APIError.networkError(urlError)
        XCTAssertEqual(error.errorDescription, "No internet connection. Please check your network.")
    }

    func testNetworkErrorTimedOutDescription() {
        let urlError = URLError(.timedOut)
        let error = APIError.networkError(urlError)
        XCTAssertEqual(error.errorDescription, "Request timed out. Please try again.")
    }
}

// MARK: - ViewModel Validation Tests

final class LoginViewModelValidationTests: XCTestCase {

    @MainActor
    func testIsValidWithEmptyEmail() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = LoginViewModel(authManager: authManager)
        vm.email = ""
        vm.password = "123456"
        XCTAssertFalse(vm.isValid)
    }

    @MainActor
    func testIsValidWithShortPassword() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = LoginViewModel(authManager: authManager)
        vm.email = "test@example.com"
        vm.password = "12345"
        XCTAssertFalse(vm.isValid)
    }

    @MainActor
    func testIsValidWithValidCredentials() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = LoginViewModel(authManager: authManager)
        vm.email = "test@example.com"
        vm.password = "12345678"
        XCTAssertTrue(vm.isValid)
    }

    @MainActor
    func testIsValidTrimsWhitespace() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = LoginViewModel(authManager: authManager)
        vm.email = "   "
        vm.password = "123456"
        XCTAssertFalse(vm.isValid)
    }

    @MainActor
    func testDefaultState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = LoginViewModel(authManager: authManager)
        XCTAssertEqual(vm.email, "")
        XCTAssertEqual(vm.password, "")
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.isLoading)
    }
}

final class SignupViewModelValidationTests: XCTestCase {

    @MainActor
    func testIsValidWithValidInput() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = SignupViewModel(authManager: authManager)
        vm.email = "new@example.com"
        vm.password = "secure123"
        vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date())
        XCTAssertTrue(vm.isValid)
    }

    @MainActor
    func testIsValidFalseWithShortPassword() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = SignupViewModel(authManager: authManager)
        vm.email = "new@example.com"
        vm.password = "abc"
        vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date())
        XCTAssertFalse(vm.isValid)
    }

    @MainActor
    func testIsValidFalseWithoutDOB() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = SignupViewModel(authManager: authManager)
        vm.email = "new@example.com"
        vm.password = "secure123"
        XCTAssertFalse(vm.isValid)
    }

    @MainActor
    func testIsUnder13() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = SignupViewModel(authManager: authManager)
        vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -10, to: Date())
        XCTAssertTrue(vm.isUnder13)
        vm.dateOfBirth = Calendar.current.date(byAdding: .year, value: -18, to: Date())
        XCTAssertFalse(vm.isUnder13)
    }

    @MainActor
    func testDefaultState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let authManager = AuthManager(apiClient: apiClient, keychainService: keychain)
        let vm = SignupViewModel(authManager: authManager)
        XCTAssertEqual(vm.displayName, "")
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.dateOfBirth)
    }
}

final class CreateNagViewModelValidationTests: XCTestCase {

    @MainActor
    func testIsValidWithoutRecipient() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let familyId = UUID()
        let vm = CreateNagViewModel(apiClient: apiClient, familyId: familyId)
        vm.recipientId = nil
        XCTAssertFalse(vm.isValid)
    }

    @MainActor
    func testIsValidWithRecipientAndFutureDue() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let familyId = UUID()
        let vm = CreateNagViewModel(apiClient: apiClient, familyId: familyId)
        vm.recipientId = UUID()
        vm.dueAt = Date().addingTimeInterval(7200) // 2 hours from now
        XCTAssertTrue(vm.isValid)
    }

    @MainActor
    func testIsValidFalseWithPastDue() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let familyId = UUID()
        let vm = CreateNagViewModel(apiClient: apiClient, familyId: familyId)
        vm.recipientId = UUID()
        vm.dueAt = Date().addingTimeInterval(-3600) // 1 hour ago
        XCTAssertFalse(vm.isValid)
    }

    @MainActor
    func testDefaultState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let familyId = UUID()
        let vm = CreateNagViewModel(apiClient: apiClient, familyId: familyId)
        XCTAssertNil(vm.recipientId)
        XCTAssertEqual(vm.category, .chores)
        XCTAssertEqual(vm.doneDefinition, .ackOnly)
        XCTAssertEqual(vm.description, "")
        XCTAssertNil(vm.recurrence)
        XCTAssertFalse(vm.didCreate)
        XCTAssertFalse(vm.isLoading)
    }
}

// MARK: - EditNag Validation Tests

final class EditNagViewModelValidationTests: XCTestCase {

    private func makeNagResponse() -> NagResponse {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "family_id": "660e8400-e29b-41d4-a716-446655440000",
            "creator_id": "770e8400-e29b-41d4-a716-446655440000",
            "recipient_id": "880e8400-e29b-41d4-a716-446655440000",
            "due_at": "2026-03-01T10:00:00+00:00",
            "category": "chores",
            "done_definition": "ack_only",
            "strategy_template": "friendly_reminder",
            "status": "open",
            "created_at": "2026-02-01T10:00:00+00:00"
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = Constants.DateFormat.iso8601.date(from: dateString) { return date }
            if let date = Constants.DateFormat.iso8601NoFractional.date(from: dateString) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return try! decoder.decode(NagResponse.self, from: json)
    }

    @MainActor
    func testHasChangesIsFalseInitially() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let nag = makeNagResponse()
        let vm = EditNagViewModel(apiClient: apiClient, nag: nag)
        XCTAssertFalse(vm.hasChanges)
    }

    @MainActor
    func testHasChangesWhenCategoryChanged() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let nag = makeNagResponse()
        let vm = EditNagViewModel(apiClient: apiClient, nag: nag)
        vm.category = .homework
        XCTAssertTrue(vm.hasChanges)
    }

    @MainActor
    func testHasChangesWhenDoneDefinitionChanged() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let nag = makeNagResponse()
        let vm = EditNagViewModel(apiClient: apiClient, nag: nag)
        vm.doneDefinition = .binaryWithNote
        XCTAssertTrue(vm.hasChanges)
    }

    @MainActor
    func testHasChangesWhenDueDateChanged() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let nag = makeNagResponse()
        let vm = EditNagViewModel(apiClient: apiClient, nag: nag)
        vm.dueAt = Date().addingTimeInterval(86400) // tomorrow
        XCTAssertTrue(vm.hasChanges)
    }

    @MainActor
    func testDefaultEditState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let nag = makeNagResponse()
        let vm = EditNagViewModel(apiClient: apiClient, nag: nag)
        XCTAssertFalse(vm.isUpdating)
        XCTAssertFalse(vm.didSave)
        XCTAssertNil(vm.errorMessage)
    }
}

// MARK: - PreferencesViewModel Default State Tests

final class PreferencesViewModelDefaultsTests: XCTestCase {

    @MainActor
    func testDefaultPreferenceValues() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let vm = PreferencesViewModel(apiClient: apiClient, familyId: UUID())
        XCTAssertFalse(vm.gamificationEnabled)
        XCTAssertFalse(vm.quietHoursEnabled)
        XCTAssertEqual(vm.quietHoursStart, "22:00")
        XCTAssertEqual(vm.quietHoursEnd, "07:00")
        XCTAssertEqual(vm.notificationFrequency, "always")
        XCTAssertEqual(vm.deliveryChannel, "push")
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isSaving)
        XCTAssertFalse(vm.didSave)
        XCTAssertNil(vm.errorMessage)
    }
}

// MARK: - IncentiveRulesViewModel Default State Tests

final class IncentiveRulesViewModelDefaultsTests: XCTestCase {

    @MainActor
    func testDefaultIncentiveRuleValues() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let vm = IncentiveRulesViewModel(apiClient: apiClient, familyId: UUID())
        XCTAssertEqual(vm.newConditionType, "nag_completed")
        XCTAssertEqual(vm.newConditionCount, 5)
        XCTAssertEqual(vm.newActionType, "bonus_points")
        XCTAssertEqual(vm.newActionAmount, 50)
        XCTAssertEqual(vm.newApprovalMode, .auto)
        XCTAssertFalse(vm.showCreateSheet)
        XCTAssertFalse(vm.isCreating)
        XCTAssertTrue(vm.rules.isEmpty)
    }
}

// MARK: - ManageMembersViewModel Default State Tests

final class ManageMembersViewModelDefaultsTests: XCTestCase {

    @MainActor
    func testDefaultManageMembersValues() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let vm = ManageMembersViewModel(apiClient: apiClient, familyId: UUID())
        XCTAssertEqual(vm.newMemberName, "")
        XCTAssertEqual(vm.newMemberRole, .child)
        XCTAssertFalse(vm.showCreateSheet)
        XCTAssertFalse(vm.isCreating)
        XCTAssertFalse(vm.isRemoving)
        XCTAssertNil(vm.memberToRemove)
        XCTAssertFalse(vm.showRemoveConfirmation)
        XCTAssertTrue(vm.members.isEmpty)
    }
}

// MARK: - FamilyViewModel Default State Tests

final class FamilyViewModelDefaultsTests: XCTestCase {

    @MainActor
    func testDefaultFamilyViewModelState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let vm = FamilyViewModel(apiClient: apiClient)
        XCTAssertNil(vm.family)
        XCTAssertTrue(vm.members.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.showCreateSheet)
        XCTAssertFalse(vm.showJoinSheet)
        XCTAssertEqual(vm.newFamilyName, "")
        XCTAssertFalse(vm.isCreating)
        XCTAssertEqual(vm.joinInviteCode, "")
        XCTAssertFalse(vm.isJoining)
    }
}

// MARK: - SafetyViewModel Default State Tests

final class SafetyViewModelDefaultsTests: XCTestCase {

    @MainActor
    func testDefaultSafetyViewModelState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let vm = SafetyViewModel(apiClient: apiClient)
        XCTAssertFalse(vm.isSubmitting)
        XCTAssertFalse(vm.reportCreated)
        XCTAssertFalse(vm.blockCreated)
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.reportReason, "")
        XCTAssertNil(vm.blockTarget)
    }
}

// MARK: - NagListViewModel Default State Tests

final class NagListViewModelDefaultsTests: XCTestCase {

    @MainActor
    func testDefaultNagListViewModelState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let vm = NagListViewModel(apiClient: apiClient)
        XCTAssertTrue(vm.nags.isEmpty)
        XCTAssertEqual(vm.filter, .open)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertNil(vm.errorMessage)
        XCTAssertFalse(vm.hasMore)
    }
}

// MARK: - NagDetailViewModel Default State Tests

final class NagDetailViewModelDefaultsTests: XCTestCase {

    @MainActor
    func testDefaultNagDetailViewModelState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let vm = NagDetailViewModel(apiClient: apiClient, nagId: UUID())
        XCTAssertNil(vm.nag)
        XCTAssertNil(vm.escalation)
        XCTAssertTrue(vm.excuses.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isUpdating)
        XCTAssertFalse(vm.isRecomputing)
        XCTAssertNil(vm.errorMessage)
    }
}

// MARK: - PaginatedResponse Tests

final class PaginatedResponseTests: XCTestCase {

    func testHasMoreWhenMoreResults() throws {
        let json = """
        {
            "items": [],
            "total": 100,
            "limit": 50,
            "offset": 0
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<NagResponse>.self, from: json)
        XCTAssertTrue(response.hasMore)
    }

    func testHasMoreFalseAtEnd() throws {
        let json = """
        {
            "items": [],
            "total": 50,
            "limit": 50,
            "offset": 0
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<NagResponse>.self, from: json)
        XCTAssertFalse(response.hasMore)
    }

    func testNextOffset() throws {
        let json = """
        {
            "items": [],
            "total": 100,
            "limit": 25,
            "offset": 25
        }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PaginatedResponse<NagResponse>.self, from: json)
        XCTAssertEqual(response.nextOffset, 50)
    }
}

// MARK: - Recurrence Tests

final class RecurrenceTests: XCTestCase {

    func testRecurrenceDisplayNames() {
        XCTAssertEqual(Recurrence.daily.displayName, "Daily")
        XCTAssertEqual(Recurrence.weekly.displayName, "Weekly")
        XCTAssertEqual(Recurrence.monthly.displayName, "Monthly")
    }

    func testRecurrenceHasSevenCases() {
        XCTAssertEqual(Recurrence.allCases.count, 7)
    }
}

// MARK: - StrategyTemplate Tests

final class StrategyTemplateTests: XCTestCase {

    func testFriendlyReminderRawValue() {
        XCTAssertEqual(StrategyTemplate.friendlyReminder.rawValue, "friendly_reminder")
    }
}

// MARK: - AuthState Tests

final class AuthStateTests: XCTestCase {

    @MainActor
    func testAuthManagerInitialState() {
        let keychain = KeychainService()
        let apiClient = APIClient(baseURL: URL(string: "http://127.0.0.1:9999")!, keychainService: keychain)
        let manager = AuthManager(apiClient: apiClient, keychainService: keychain)
        XCTAssertNil(manager.currentUser)
        XCTAssertFalse(manager.isAuthenticated)
    }
}

// MARK: - Version Constants Tests

final class VersionConstantsTests: XCTestCase {

    func testClientAPIVersionIsSemver() {
        let parts = Constants.Version.clientAPIVersion.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
        for part in parts {
            XCTAssertNotNil(Int(part))
        }
    }
}
