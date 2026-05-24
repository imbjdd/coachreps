import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var app: AppState
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.background)
        .task { await app.refreshTeam() }
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
                Text("Leaderboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                if !app.teamCode.isEmpty {
                    Text(app.teamCode)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Theme.textTertiary)
                }
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background.overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom))
    }

    @ViewBuilder
    private var content: some View {
        if app.teamCode.isEmpty {
            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "person.3.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Theme.textTertiary)
                Text("Join a team")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Go to Settings → Team to enter a code\nand see your teammates here.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
        } else if app.teamLeaderboard.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Text("No drills logged in team \(app.teamCode) yet")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Text("Be the first to set a top score.")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
            }
            .padding(24)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(Array(app.teamLeaderboard.enumerated()), id: \.offset) { idx, row in
                        LeaderboardRow(rank: idx + 1, name: row.name, totalXP: row.totalXP, drills: row.drills, avgScore: row.avgScore, isYou: row.name == app.displayName)
                    }
                }
                .padding(20)
            }
        }
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let name: String
    let totalXP: Int
    let drills: Int
    let avgScore: Int
    let isYou: Bool

    var rankColor: Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.68, blue: 0.20)
        case 2: return Color(red: 0.65, green: 0.65, blue: 0.65)
        case 3: return Color(red: 0.75, green: 0.50, blue: 0.30)
        default: return Theme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(rank <= 3 ? rankColor : Theme.textTertiary)
                .frame(width: 24)
            ZStack {
                Circle().fill(isYou ? Theme.accent : Theme.surfaceMuted).frame(width: 38, height: 38)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isYou ? .white : Theme.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                    if isYou {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent))
                    }
                }
                Text("\(drills) drill\(drills == 1 ? "" : "s") · avg \(avgScore)")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(totalXP)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("XP")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(isYou ? Theme.highlightTint.opacity(0.4) : Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
