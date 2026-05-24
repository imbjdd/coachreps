import SwiftUI

struct HomeView: View {
    var onOpenDrill: (Drill) -> Void

    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            xpStripe

            if app.isLoading && app.drills.isEmpty {
                loadingPlaceholder
            } else if let err = app.loadError, app.drills.isEmpty {
                errorBox(err)
            } else if app.hasCompletedDailyToday {
                dailyDoneHero
                if let bonus = app.bonusDrill {
                    bonusDrillRow(bonus)
                }
            } else if let drill = app.todayDrill {
                heroDrill(drill)
            }

            statsRow

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(greeting)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                Text(app.displayName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
            }
            Spacer()
            StreakBadge(count: app.stats.streak)
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var xpStripe: some View {
        let p = GameSystem.xpProgress(forTotalXP: app.stats.totalXP)
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accent).frame(width: 28, height: 28)
                Text("\(p.level)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Level \(p.level)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Text("\(p.current) / \(p.needed) XP")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surfaceMuted)
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(6, geo.size.width * CGFloat(p.needed > 0 ? Double(p.current) / Double(p.needed) : 0)))
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 8) {
            ProgressView().tint(Theme.textSecondary)
            Text("Loading drills...")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.surfaceMuted))
    }

    private func errorBox(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Connection failed")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text(msg)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            Button("Retry") {
                Task { await app.bootstrap() }
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceMuted))
    }

    private func heroDrill(_ drill: Drill) -> some View {
        Button { onOpenDrill(drill) } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("TODAY'S DRILL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(Theme.highlight)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .medium))
                        Text("3 min")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("The client says")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Text("\u{201C}\(drill.clientLine)\u{201D}")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: drill.type.icon)
                            .font(.system(size: 11, weight: .medium))
                        Text(drill.type.shortLabel)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.surface))

                    Spacer()

                    HStack(spacing: 6) {
                        Text("Start")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.accent))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.highlightTint))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.highlight.opacity(0.20), lineWidth: 1))
            .shadow(color: Theme.highlight.opacity(0.10), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var dailyDoneHero: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.success).frame(width: 44, height: 44)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily drill done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(streakLine)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.success.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.success.opacity(0.20), lineWidth: 1))
    }

    private var streakLine: String {
        let s = app.stats.streak
        if s == 0 { return "Nice work. Keep building momentum." }
        if s == 1 { return "1-day streak started. Don't break it." }
        return "\(s)-day streak. Don't break it."
    }

    private func bonusDrillRow(_ drill: Drill) -> some View {
        Button { onOpenDrill(drill) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("BONUS DRILL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(Theme.textTertiary)
                    Spacer()
                    Text("+ extra XP")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.accent)
                }
                Text(drill.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\u{201C}\(drill.clientLine)\u{201D}")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: drill.type.icon)
                            .font(.system(size: 10, weight: .medium))
                        Text(drill.type.shortLabel)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.surfaceMuted))
                    Spacer()
                    HStack(spacing: 5) {
                        Text("Train more")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            MiniStat(label: "Avg pace", value: app.weeklyWPM.map { "\($0)" } ?? "–", unit: "wpm")
            MiniStat(label: "Drills", value: "\(app.stats.drillsCompleted)", unit: "total")
            MiniStat(label: "Total XP", value: "\(app.stats.totalXP)", unit: "pts")
        }
    }

}

struct MiniStat: View {
    let label: String
    let value: String
    let unit: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundColor(Theme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}
