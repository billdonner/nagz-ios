import SwiftUI
import NagzAI

struct AIInsightsSection: View {
    let nagId: UUID
    let nag: NagResponse?
    @Environment(\.aiService) private var aiService

    @State private var tone: ToneSelectResponse?
    @State private var coaching: CoachingResponse?
    @State private var prediction: PredictCompletionResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(nagId: UUID, nag: NagResponse? = nil) {
        self.nagId = nagId
        self.nag = nag
    }

    var body: some View {
        if aiService != nil || nag != nil {
            if isLoading {
                Section("AI Insights") {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyzing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .task { await fetchInsights() }
            } else if tone != nil || coaching != nil || prediction != nil {
                Section("AI Insights") {
                    if let tone {
                        ToneRow(tone: tone)
                    }
                    if let coaching {
                        CoachingRow(coaching: coaching)
                    }
                    if let prediction {
                        PredictionRow(prediction: prediction)
                    }
                }
            } else if let errorMessage {
                Section("AI Insights") {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func fetchInsights() async {
        guard let aiService else {
            // No AI service — try direct heuristics if we have nag data
            await tryDirectHeuristics()
            isLoading = false
            return
        }

        DebugLogger.shared.log("AIInsightsSection: fetching for nag \(nagId)")

        do {
            tone = try await aiService.selectTone(nagId: nagId)
        } catch {
            DebugLogger.shared.log("AIInsightsSection: selectTone failed: \(error)", level: .warning)
        }

        do {
            coaching = try await aiService.coaching(nagId: nagId)
        } catch {
            DebugLogger.shared.log("AIInsightsSection: coaching failed: \(error)", level: .warning)
        }

        do {
            prediction = try await aiService.predictCompletion(nagId: nagId)
        } catch {
            DebugLogger.shared.log("AIInsightsSection: predictCompletion failed: \(error)", level: .warning)
        }

        // If all service calls failed, try direct heuristics as last resort
        if tone == nil && coaching == nil && prediction == nil {
            DebugLogger.shared.log("AIInsightsSection: all service calls failed, trying direct heuristics", level: .warning)
            await tryDirectHeuristics()
        }

        if tone == nil && coaching == nil && prediction == nil {
            errorMessage = "AI insights unavailable"
        }
        isLoading = false
    }

    private func tryDirectHeuristics() async {
        guard let nag else { return }

        // Derive synthetic stats from the nag's own state so results vary per nag
        let isOverdue = nag.status == .open && nag.dueAt < Date()
        let missCount7D: Int
        let streak: Int
        let overallTotal: Int
        let overallCompleted: Int

        switch nag.status {
        case .completed:
            missCount7D = 0
            streak = 1
            overallTotal = 1
            overallCompleted = 1
        case .missed:
            missCount7D = 1
            streak = 0
            overallTotal = 1
            overallCompleted = 0
        case .open where isOverdue:
            missCount7D = 1
            streak = 0
            overallTotal = 1
            overallCompleted = 0
        default:
            missCount7D = 0
            streak = nag.category == .homework ? 1 : 0
            overallTotal = 0
            overallCompleted = 0
        }

        let context = NagzAI.AIContext(
            nagId: nag.id,
            userId: nag.recipientId,
            familyId: nag.familyId ?? nag.creatorId,
            category: nag.category.rawValue,
            status: nag.status.rawValue,
            dueAt: nag.dueAt,
            missCount7D: missCount7D,
            streak: streak,
            timeConflictCount: 0,
            categoryTotal: overallTotal,
            categoryCompleted: overallCompleted,
            overallTotal: overallTotal,
            overallCompleted: overallCompleted
        )

        let router = NagzAI.Router(preferHeuristic: true)

        if let result = try? await router.selectTone(context: context) {
            tone = ToneSelectResponse(
                nagId: nag.id,
                tone: AITone(rawValue: result.tone.rawValue) ?? .neutral,
                missCount7D: result.missCount7D,
                streak: result.streak,
                reason: result.reason
            )
        }

        if let result = try? await router.coaching(context: context) {
            coaching = CoachingResponse(
                nagId: nag.id,
                tip: result.tip,
                category: result.category,
                scenario: result.scenario
            )
        }

        if let result = try? await router.predictCompletion(context: context) {
            prediction = PredictCompletionResponse(
                nagId: nag.id,
                likelihood: result.likelihood,
                suggestedReminderTime: result.suggestedReminderTime,
                factors: result.factors.map { CompletionFactor(name: $0.name, value: $0.value) }
            )
        }
    }
}

// MARK: - Subviews

private struct ToneRow: View {
    let tone: ToneSelectResponse

    var body: some View {
        HStack(spacing: 8) {
            Text(tone.tone.rawValue.capitalized)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(toneColor)
                .background(toneColor.opacity(0.15))
                .clipShape(Capsule())

            Text(tone.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var toneColor: Color {
        switch tone.tone {
        case .neutral: .blue
        case .supportive: .green
        case .firm: .red
        }
    }
}

private struct CoachingRow: View {
    let coaching: CoachingResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)
                Text(coaching.tip)
                    .font(.subheadline)
            }
            Text(coaching.scenario)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PredictionRow: View {
    let prediction: PredictCompletionResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Completion Likelihood")
                    .font(.subheadline)
                Spacer()
                Text("\(Int(prediction.likelihood * 100))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(likelihoodColor)
            }
            ProgressView(value: prediction.likelihood)
                .tint(likelihoodColor)
            if let reminderTime = prediction.suggestedReminderTime {
                Text("Suggested reminder: \(reminderTime.relativeDisplay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var likelihoodColor: Color {
        if prediction.likelihood >= 0.7 { return .green }
        if prediction.likelihood >= 0.4 { return .orange }
        return .red
    }
}
