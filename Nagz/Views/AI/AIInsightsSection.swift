import SwiftUI

struct AIInsightsSection: View {
    let nagId: UUID
    @Environment(\.aiService) private var aiService

    @State private var tone: ToneSelectResponse?
    @State private var coaching: CoachingResponse?
    @State private var prediction: PredictCompletionResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        if aiService != nil {
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
            isLoading = false
            return
        }

        DebugLogger.shared.log("AIInsightsSection: fetching for nag \(nagId)")

        var errors: [String] = []

        do {
            tone = try await aiService.selectTone(nagId: nagId)
        } catch {
            DebugLogger.shared.log("AIInsightsSection: selectTone failed: \(error)", level: .warning)
            errors.append("tone: \(error.localizedDescription)")
        }

        do {
            coaching = try await aiService.coaching(nagId: nagId)
        } catch {
            DebugLogger.shared.log("AIInsightsSection: coaching failed: \(error)", level: .warning)
            errors.append("coaching: \(error.localizedDescription)")
        }

        do {
            prediction = try await aiService.predictCompletion(nagId: nagId)
        } catch {
            DebugLogger.shared.log("AIInsightsSection: predictCompletion failed: \(error)", level: .warning)
            errors.append("prediction: \(error.localizedDescription)")
        }

        if tone == nil && coaching == nil && prediction == nil {
            let detail = errors.joined(separator: "; ")
            errorMessage = "AI insights unavailable: \(detail)"
            DebugLogger.shared.log("AIInsightsSection: all failed — \(detail)", level: .error)
        }
        isLoading = false
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
