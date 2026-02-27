import SwiftUI

struct AIInsightsSection: View {
    let nagId: UUID
    @Environment(\.aiService) private var aiService

    @State private var tone: ToneSelectResponse?
    @State private var coaching: CoachingResponse?
    @State private var prediction: PredictCompletionResponse?
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded, tone != nil || coaching != nil || prediction != nil {
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
            }
        }
        .task { await fetchInsights() }
    }

    private func fetchInsights() async {
        guard let aiService else {
            loaded = true
            return
        }

        async let toneResult = try? aiService.selectTone(nagId: nagId)
        async let coachingResult = try? aiService.coaching(nagId: nagId)
        async let predictionResult = try? aiService.predictCompletion(nagId: nagId)

        let (t, c, p) = await (toneResult, coachingResult, predictionResult)
        tone = t
        coaching = c
        prediction = p
        loaded = true
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
