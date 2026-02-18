import Foundation

struct WeeklyReportResponse: Decodable, Sendable {
    let familyId: UUID
    let periodStart: Date
    let metrics: ReportMetrics
}

struct ReportMetrics: Decodable, Sendable {
    let totalNags: Int
    let completed: Int
    let missed: Int
}

struct FamilyMetricsResponse: Decodable, Sendable {
    let familyId: UUID
    let fromDate: Date?
    let toDate: Date?
    let totalNags: Int
    let completed: Int
    let missed: Int
    let completionRate: Double
}
