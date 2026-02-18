import AppIntents

enum NagCategoryAppEnum: String, AppEnum {
    case chores
    case meds
    case homework
    case appointments
    case other

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Category" }

    static var caseDisplayRepresentations: [NagCategoryAppEnum: DisplayRepresentation] {
        [
            .chores: "Chores",
            .meds: "Meds",
            .homework: "Homework",
            .appointments: "Appointments",
            .other: "Other"
        ]
    }

    var nagCategory: NagCategory {
        NagCategory(rawValue: rawValue) ?? .other
    }
}
