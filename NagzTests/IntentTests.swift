import Testing
import Foundation
@testable import Nagz

@Suite("Intent Tests", .serialized)
struct IntentTests {

    // MARK: - NagCategoryAppEnum

    @Test("NagCategoryAppEnum covers all NagCategory cases")
    func nagCategoryAppEnumCoversAll() {
        let appEnumCases = NagCategoryAppEnum.allCases
        let nagCategoryCases = NagCategory.allCases

        #expect(appEnumCases.count == nagCategoryCases.count)

        for nagCategory in nagCategoryCases {
            let appEnum = NagCategoryAppEnum(rawValue: nagCategory.rawValue)
            #expect(appEnum != nil, "Missing NagCategoryAppEnum case for \(nagCategory.rawValue)")
            #expect(appEnum?.nagCategory == nagCategory)
        }
    }

    @Test("NagCategoryAppEnum caseDisplayRepresentations covers all cases")
    func nagCategoryAppEnumDisplayRepresentations() {
        for enumCase in NagCategoryAppEnum.allCases {
            let representation = NagCategoryAppEnum.caseDisplayRepresentations[enumCase]
            #expect(representation != nil, "Missing display representation for \(enumCase)")
        }
    }

    // MARK: - NagzIntentError

    @Test("NagzIntentError localizedStringResource values")
    func nagzIntentErrorMessages() {
        let notLoggedIn = NagzIntentError.notLoggedIn.localizedStringResource
        #expect(notLoggedIn.key == "Please open Nagz and log in first.")

        let noFamily = NagzIntentError.noFamily.localizedStringResource
        #expect(noFamily.key == "No family selected. Open Nagz and join a family first.")

        let notPermitted = NagzIntentError.notPermitted.localizedStringResource
        #expect(notPermitted.key == "Your role doesn't have permission for this action.")

        let invalidNagId = NagzIntentError.invalidNagId.localizedStringResource
        #expect(invalidNagId.key == "Invalid nag ID. The nag may have been deleted.")
    }

    // MARK: - NagEntity

    @Test("NagEntity displayRepresentation formatting")
    func nagEntityDisplayRepresentation() {
        let entity = NagEntity(
            id: UUID().uuidString,
            category: "chores",
            status: "open",
            dueAt: Date().addingTimeInterval(3600),
            recipientName: "John"
        )

        let title = entity.displayRepresentation.title
        #expect(String(localized: title) == "Chores — John")
    }

    @Test("NagEntity init from NagResponse")
    func nagEntityFromResponse() {
        let nagId = UUID()
        let familyId = UUID()
        let creatorId = UUID()
        let recipientId = UUID()
        let dueDate = Date().addingTimeInterval(7200)

        let nag = NagResponse(
            id: nagId,
            familyId: familyId,
            connectionId: nil,
            creatorId: creatorId,
            recipientId: recipientId,
            creatorDisplayName: "Mom",
            recipientDisplayName: "Alice",
            dueAt: dueDate,
            category: .homework,
            doneDefinition: .binaryCheck,
            description: "Math worksheet",
            strategyTemplate: .friendlyReminder,
            recurrence: nil,
            status: .open,
            createdAt: Date()
        )

        let entity = NagEntity(from: nag, recipientName: "Alice")
        #expect(entity.id == nagId.uuidString)
        #expect(entity.category == "homework")
        #expect(entity.status == "open")
        #expect(entity.recipientName == "Alice")
        #expect(entity.nagDescription == "Math worksheet")
        #expect(entity.dueAt == dueDate)
    }

    // MARK: - FamilyMemberEntity

    @Test("FamilyMemberEntity displayRepresentation")
    func familyMemberEntityDisplayRepresentation() {
        let entity = FamilyMemberEntity(
            id: UUID().uuidString,
            displayName: "Jane",
            role: "guardian"
        )

        let title = entity.displayRepresentation.title
        #expect(String(localized: title) == "Jane")
    }

    @Test("FamilyMemberEntity init from MemberDetail")
    func familyMemberEntityFromMemberDetail() {
        let userId = UUID()
        let familyId = UUID()
        let member = MemberDetail(
            userId: userId,
            displayName: "Bob",
            familyId: familyId,
            role: .child,
            status: .active,
            joinedAt: Date()
        )

        let entity = FamilyMemberEntity(from: member)
        #expect(entity.id == userId.uuidString)
        #expect(entity.displayName == "Bob")
        #expect(entity.role == "child")
    }

    @Test("FamilyMemberEntity falls back to truncated userId when displayName is nil")
    func familyMemberEntityNilDisplayName() {
        let userId = UUID()
        let member = MemberDetail(
            userId: userId,
            displayName: nil,
            familyId: UUID(),
            role: .participant,
            status: .active,
            joinedAt: Date()
        )

        let entity = FamilyMemberEntity(from: member)
        #expect(entity.displayName == String(userId.uuidString.prefix(8)))
    }

    // MARK: - IntentServiceContainer UserDefaults

    @Test("IntentServiceContainer.currentFamilyId throws when no UserDefaults key")
    func currentFamilyIdThrowsWhenMissing() {
        UserDefaults.standard.removeObject(forKey: "nagz_family_id")
        #expect(throws: NagzIntentError.self) {
            _ = try IntentServiceContainer.currentFamilyId()
        }
    }

    @Test("IntentServiceContainer.currentFamilyId returns UUID when set")
    func currentFamilyIdReturnsUUID() throws {
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: "nagz_family_id")
        let result = try IntentServiceContainer.currentFamilyId()
        #expect(result == id)
        UserDefaults.standard.removeObject(forKey: "nagz_family_id")
    }

    @Test("IntentServiceContainer.currentUserId throws when no UserDefaults key")
    func currentUserIdThrowsWhenMissing() {
        UserDefaults.standard.removeObject(forKey: "nagz_user_id")
        #expect(throws: NagzIntentError.self) {
            _ = try IntentServiceContainer.currentUserId()
        }
    }

    @Test("IntentServiceContainer.currentUserId returns UUID when set")
    func currentUserIdReturnsUUID() throws {
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: "nagz_user_id")
        let result = try IntentServiceContainer.currentUserId()
        #expect(result == id)
        UserDefaults.standard.removeObject(forKey: "nagz_user_id")
    }

    @Test("IntentServiceContainer.currentFamilyId throws for invalid UUID string")
    func currentFamilyIdThrowsForInvalidUUID() {
        UserDefaults.standard.set("not-a-uuid", forKey: "nagz_family_id")
        #expect(throws: NagzIntentError.self) {
            _ = try IntentServiceContainer.currentFamilyId()
        }
        UserDefaults.standard.removeObject(forKey: "nagz_family_id")
    }
}
