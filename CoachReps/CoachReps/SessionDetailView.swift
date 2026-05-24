import SwiftUI

private struct OpenSessionKey: EnvironmentKey {
    static let defaultValue: (DrillSession) -> Void = { _ in }
}

extension EnvironmentValues {
    var openSession: (DrillSession) -> Void {
        get { self[OpenSessionKey.self] }
        set { self[OpenSessionKey.self] = newValue }
    }
}

struct SessionDetailView: View {
    let session: DrillSession
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    overviewCard
                    metricsGrid
                    analysisCard
                    improvementsCard
                    if !session.transcript.isEmpty { transcriptCard }
                }
                .padding(20)
            }
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surfaceMuted))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 0) {
                Text("Récap du drill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(dateLabel)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.8)
                    .foregroundColor(Theme.textTertiary)
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background.overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom))
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: session.completedAt).uppercased()
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.drillTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(session.drillType.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                ScoreBadge(score: session.score)
            }
            HStack(spacing: 8) {
                Text("+\(session.xp) XP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.accent))
                Text(String(format: "%.1fs enregistrés", session.durationSec))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            metricCell(label: "Pace", value: "\(session.wpm)", unit: "wpm")
            metricCell(label: "Filler words", value: "\(session.fillerCount)", unit: "")
            metricCell(label: "Pauses", value: "\(session.pauseCount)", unit: "")
            metricCell(label: "Pitch range", value: String(format: "%.1f", session.pitchVariation), unit: "st")
        }
    }

    private func metricCell(label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var analysisCard: some View {
        if !session.analysis.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("ANALYSE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                Text(session.analysis)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceMuted))
        }
    }

    @ViewBuilder
    private var improvementsCard: some View {
        if !session.improvements.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("À CORRIGER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                ForEach(Array(session.improvements.enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Theme.accent))
                        Text(item)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textPrimary)
                            .lineSpacing(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CE QUE TU AS DIT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            Text("\u{201C}\(session.transcript)\u{201D}")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceMuted))
    }
}
