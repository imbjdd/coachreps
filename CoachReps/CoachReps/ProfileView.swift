import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    var onShowSessions: () -> Void
    var onShowBadges: () -> Void
    var onShowSettings: () -> Void
    var onShowLeaderboard: () -> Void
    var onStartFirstDrill: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            profileHeader
            if app.sessions.isEmpty {
                emptyProfileContent
            } else {
                levelCard
                if app.evolutionPoints.count >= 2 { trendCard }
                teamRow
                badgesStrip
                statsGrid
                recentSessionRow
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    private var emptyProfileContent: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 18)
            ZStack {
                Circle().fill(Theme.highlightTint).frame(width: 88, height: 88)
                Image(systemName: "waveform")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Theme.highlight)
            }
            VStack(spacing: 8) {
                Text("Aucun drill encore")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Ton niveau, tes badges et tes patterns apparaissent ici\naprès ton premier drill.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            PrimaryButton(title: "Commencer mon premier drill", icon: "play.fill") {
                onStartFirstDrill()
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.border, lineWidth: 1))
    }

    private var trendCard: some View {
        let pts = app.evolutionPoints
        let first = pts.first ?? 0
        let last = pts.last ?? 0
        let delta = last - first
        return HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ÉVOLUTION DÉBIT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Theme.textTertiary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(last))")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text("wpm")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                Text(deltaLabel(delta))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(deltaColor(delta))
            }
            Spacer()
            EvolutionChart(points: pts)
                .frame(width: 140, height: 46)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func deltaLabel(_ d: Double) -> String {
        if abs(d) < 1 { return "Stable" }
        let sign = d > 0 ? "+" : ""
        return "\(sign)\(Int(d)) wpm vs début"
    }
    private func deltaColor(_ d: Double) -> Color {
        if d > 0 { return Theme.warning } // faster — not always good
        if d < 0 { return Theme.success } // slower — usually good
        return Theme.textSecondary
    }

    private var teamRow: some View {
        Button(action: onShowLeaderboard) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(app.teamCode.isEmpty ? Theme.surfaceMuted : Theme.highlightTint)
                        .frame(width: 38, height: 38)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(app.teamCode.isEmpty ? Theme.textTertiary : Theme.highlight)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.teamCode.isEmpty ? "Rejoindre une équipe" : "Équipe \(app.teamCode)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Text(app.teamCode.isEmpty ? "Compare-toi au top performer" : "\(app.teamMembers.count) membre\(app.teamMembers.count == 1 ? "" : "s") · \(app.teamSessions.count) drill\(app.teamSessions.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.surfaceMuted)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                Text(app.initial)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Niveau \(app.stats.level) · \(app.stats.drillsCompleted) drills")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button(action: onShowSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    private var levelCard: some View {
        let p = GameSystem.xpProgress(forTotalXP: app.stats.totalXP)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Text("NIVEAU")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.textTertiary)
                    Text("\(p.level)")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TOTAL XP")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.textTertiary)
                    Text("\(app.stats.totalXP)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceMuted)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(8, geo.size.width * CGFloat(p.needed > 0 ? Double(p.current) / Double(p.needed) : 0)))
                }
            }
            .frame(height: 8)
            Text("\(p.needed - p.current) XP avant le niveau \(p.level + 1)")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private var badgesStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BADGES")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                Button(action: onShowBadges) {
                    HStack(spacing: 4) {
                        Text("\(app.stats.unlockedBadges.count) / \(GameSystem.allBadges.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            // continues below
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GameSystem.allBadges) { badge in
                        SmallBadgeChip(badge: badge, unlocked: app.stats.unlockedBadges.contains(badge.id))
                    }
                }
            }
        }
    }

    private var statsGrid: some View {
        let derived = derivedPatterns()
        return VStack(alignment: .leading, spacing: 8) {
            Text("TES PATTERNS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            if derived.isEmpty {
                Text("Fais un drill pour voir tes patterns")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceMuted))
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(derived) { p in
                        PatternMiniCard(stat: p)
                    }
                }
            }
        }
    }

    @Environment(\.openSession) private var openSession

    private var recentSessionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DERNIER DRILL")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                if !app.sessions.isEmpty {
                    Button(action: onShowSessions) {
                        HStack(spacing: 4) {
                            Text("Historique")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if let s = app.sessions.first {
                Button { openSession(s) } label: { SessionRow(session: s) }
                    .buttonStyle(.plain)
            } else {
                Text("Aucun drill complété pour l'instant")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceMuted))
            }
        }
    }

    private func derivedPatterns() -> [DerivedPattern] {
        guard !app.sessions.isEmpty else { return [] }
        let count = Double(app.sessions.count)
        let avgFillers = app.sessions.map { Double($0.fillerCount) }.reduce(0, +) / count
        let avgWpm = app.sessions.map { Double($0.wpm) }.reduce(0, +) / count
        let avgPauses = app.sessions.map { Double($0.pauseCount) }.reduce(0, +) / count
        let avgPitch = app.sessions.map { $0.pitchVariation }.reduce(0, +) / count

        return [
            DerivedPattern(label: "Avg pace", detail: "\(Int(avgWpm)) wpm", good: avgWpm >= 130 && avgWpm <= 160),
            DerivedPattern(label: "Fillers / drill", detail: String(format: "%.1f", avgFillers), good: avgFillers < 3),
            DerivedPattern(label: "Pauses / drill", detail: String(format: "%.1f", avgPauses), good: avgPauses >= 1),
            DerivedPattern(label: "Pitch range", detail: String(format: "%.1f st", avgPitch), good: avgPitch >= 3)
        ]
    }
}

struct DerivedPattern: Identifiable {
    let id = UUID()
    let label: String
    let detail: String
    let good: Bool
}

struct PatternMiniCard: View {
    let stat: DerivedPattern
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(stat.label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(Theme.textTertiary)
            HStack(spacing: 6) {
                Text(stat.detail)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Image(systemName: stat.good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(stat.good ? Theme.success : Theme.danger)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}

struct SmallBadgeChip: View {
    let badge: Badge
    let unlocked: Bool
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? Theme.accent : Theme.surfaceMuted)
                    .frame(width: 42, height: 42)
                Image(systemName: badge.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(unlocked ? .white : Theme.textTertiary)
            }
            Text(badge.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(unlocked ? Theme.textPrimary : Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 56)
        }
        .opacity(unlocked ? 1.0 : 0.55)
    }
}

struct SessionRow: View {
    let session: DrillSession
    var body: some View {
        HStack(spacing: 12) {
            ScoreCircle(score: session.score)
            VStack(alignment: .leading, spacing: 3) {
                Text(session.drillTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text("\(session.wpm) wpm · \(session.fillerCount) fillers · +\(session.xp) XP")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}

struct ScoreCircle: View {
    let score: Int
    var color: Color {
        if score >= 80 { return Theme.success }
        if score >= 60 { return Theme.warning }
        return Theme.danger
    }
    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.12))
            Text("\(score)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
        }
        .frame(width: 38, height: 38)
    }
}

// MARK: - Detail views (pushed from profile)

struct AllBadgesView: View {
    @EnvironmentObject var app: AppState
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(GameSystem.allBadges) { b in
                        BigBadgeChip(badge: b, unlocked: app.stats.unlockedBadges.contains(b.id))
                    }
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
            Text("Badges \(app.stats.unlockedBadges.count) / \(GameSystem.allBadges.count)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background.overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom))
    }
}

struct BigBadgeChip: View {
    let badge: Badge
    let unlocked: Bool
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(unlocked ? Theme.accent : Theme.surfaceMuted)
                    .frame(width: 56, height: 56)
                Image(systemName: badge.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(unlocked ? .white : Theme.textTertiary)
            }
            Text(badge.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(unlocked ? Theme.textPrimary : Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(badge.description)
                .font(.system(size: 9))
                .foregroundColor(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(unlocked ? Theme.surface : Theme.background))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        .opacity(unlocked ? 1.0 : 0.55)
    }
}

struct SessionHistoryView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.openSession) private var openSession
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(app.sessions) { s in
                        Button { openSession(s) } label: {
                            SessionRow(session: s)
                        }
                        .buttonStyle(.plain)
                    }
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
            Text("Historique · \(app.sessions.count)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background.overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom))
    }
}

struct EvolutionChart: View {
    let points: [Double]

    var body: some View {
        GeometryReader { geo in
            let minV = (points.min() ?? 0) - 2
            let maxV = (points.max() ?? 1) + 2
            let range = max(maxV - minV, 1)
            let step = points.count > 1 ? geo.size.width / CGFloat(points.count - 1) : geo.size.width

            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height))
                    for (i, v) in points.enumerated() {
                        let x = CGFloat(i) * step
                        let y = geo.size.height - CGFloat((v - minV) / range) * geo.size.height
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Theme.accent.opacity(0.18), Theme.accent.opacity(0)], startPoint: .top, endPoint: .bottom))

                Path { p in
                    for (i, v) in points.enumerated() {
                        let x = CGFloat(i) * step
                        let y = geo.size.height - CGFloat((v - minV) / range) * geo.size.height
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                if let last = points.last {
                    let x = geo.size.width
                    let y = geo.size.height - CGFloat((last - minV) / range) * geo.size.height
                    Circle()
                        .fill(Theme.surface)
                        .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Overlays

struct LevelUpOverlay: View {
    let level: Int
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.accent).frame(width: 76, height: 76)
                    Image(systemName: "star.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("NIVEAU UP")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Theme.textTertiary)
                Text("Niveau \(level)")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Button("Continuer") { onDismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
            }
            .padding(26)
            .frame(maxWidth: 320)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surface))
        }
    }
}

struct BadgeUnlockOverlay: View {
    let badges: [Badge]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            VStack(spacing: 16) {
                Text(badges.count == 1 ? "Badge débloqué" : "\(badges.count) badges débloqués")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                VStack(spacing: 12) {
                    ForEach(badges) { b in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Theme.accent).frame(width: 44, height: 44)
                                Image(systemName: b.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(b.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Theme.textPrimary)
                                Text(b.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                }
                Button("OK") { onDismiss() }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
            }
            .padding(22)
            .frame(maxWidth: 340)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surface))
        }
    }
}
