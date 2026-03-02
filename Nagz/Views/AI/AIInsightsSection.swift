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
    @State private var appeared = false

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
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .opacity(appeared ? 0.4 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: appeared)
                    }
                }
                .task { await fetchInsights() }
                .onAppear { appeared = true }
            } else if tone != nil || coaching != nil || prediction != nil {
                Section("AI Insights") {
                    if let tone {
                        ToneRow(tone: tone, appeared: appeared)
                    }
                    if let coaching {
                        CoachingRow(coaching: coaching, appeared: appeared)
                    }
                    if let prediction {
                        PredictionRow(prediction: prediction, appeared: appeared)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.4)) {
                        appeared = true
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
            appeared = false
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
        appeared = false
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
    let appeared: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toneIcon)
                .font(.body)
                .foregroundStyle(toneColor)

            Text(tone.tone.rawValue.capitalized)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(toneColor)
                .background(toneColor.opacity(0.15))
                .clipShape(Capsule())

            Text(tone.reason)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .animation(.easeOut(duration: 0.4), value: appeared)
    }

    private var toneIcon: String {
        switch tone.tone {
        case .supportive: "heart.fill"
        case .firm: "exclamationmark.triangle.fill"
        case .neutral: "hand.raised.fill"
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
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.body)
                Text(coaching.tip)
                    .font(.body)
            }
            Text(coaching.scenario)
                .font(.subheadline)
                .foregroundStyle(.purple)
        }
        .padding(10)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
    }
}

private struct PredictionRow: View {
    let prediction: PredictCompletionResponse
    let appeared: Bool

    @State private var animatedLikelihood: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Completion Likelihood")
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(Int(prediction.likelihood * 100))%")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(likelihoodColor)
            }
            ProgressView(value: animatedLikelihood)
                .tint(likelihoodColor)
                .scaleEffect(y: 2, anchor: .center)
                .padding(.vertical, 2)
            if let reminderTime = prediction.suggestedReminderTime {
                Text("Suggested reminder: \(reminderTime.relativeDisplay)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
        .onChange(of: appeared) {
            if appeared {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    animatedLikelihood = prediction.likelihood
                }
            }
        }
    }

    private var likelihoodColor: Color {
        if prediction.likelihood >= 0.7 { return .green }
        if prediction.likelihood >= 0.4 { return .orange }
        return .red
    }
}
