import Foundation

struct Badge: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
}

enum GameSystem {
    // XP table: each level requires +50 more XP than the previous
    // L1->L2: 100, L2->L3: 150, L3->L4: 200, etc.
    static func xpForLevel(_ level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (1..<level).map { 100 + ($0 - 1) * 50 }.reduce(0, +)
    }

    static func level(forTotalXP xp: Int) -> Int {
        var lvl = 1
        while xpForLevel(lvl + 1) <= xp { lvl += 1 }
        return lvl
    }

    static func xpProgress(forTotalXP xp: Int) -> (current: Int, needed: Int, level: Int) {
        let lvl = level(forTotalXP: xp)
        let base = xpForLevel(lvl)
        let next = xpForLevel(lvl + 1)
        return (xp - base, next - base, lvl)
    }

    /// XP awarded for a completed drill based on score (0-100).
    /// Base 20 XP + score/2. So 100/100 → 70 XP, 50/100 → 45 XP.
    static func xpAwarded(forScore score: Int) -> Int {
        20 + max(0, min(100, score)) / 2
    }

    static let allBadges: [Badge] = [
        Badge(id: "first_drill", name: "First drill", description: "Complete your first drill", icon: "checkmark.seal.fill"),
        Badge(id: "streak_3", name: "3 day streak", description: "Practice 3 days in a row", icon: "flame.fill"),
        Badge(id: "streak_7", name: "One week", description: "Practice 7 days in a row", icon: "flame.circle.fill"),
        Badge(id: "streak_30", name: "One month", description: "Practice 30 days in a row", icon: "crown.fill"),
        Badge(id: "drills_10", name: "10 drills", description: "Complete 10 drills", icon: "10.circle.fill"),
        Badge(id: "drills_50", name: "50 drills", description: "Complete 50 drills", icon: "50.circle.fill"),
        Badge(id: "perfect_score", name: "Sharp shooter", description: "Score 90+ on a drill", icon: "star.circle.fill"),
        Badge(id: "no_fillers", name: "Zero fillers", description: "Drill without a single filler", icon: "mouth.fill"),
        Badge(id: "level_5", name: "Level 5", description: "Reach level 5", icon: "5.circle.fill"),
        Badge(id: "level_10", name: "Level 10", description: "Reach level 10", icon: "10.circle.fill"),
    ]

    static func badge(for id: String) -> Badge? {
        allBadges.first(where: { $0.id == id })
    }

    /// Compute newly unlocked badges given the latest state.
    static func newlyUnlocked(
        stats: UserStatsDTO,
        latestScore: Int,
        latestFillerCount: Int
    ) -> [Badge] {
        var unlocked: [Badge] = []
        let already = Set(stats.unlockedBadges)

        if stats.drillsCompleted >= 1 && !already.contains("first_drill") {
            unlocked.append(badge(for: "first_drill")!)
        }
        if stats.streak >= 3 && !already.contains("streak_3") {
            unlocked.append(badge(for: "streak_3")!)
        }
        if stats.streak >= 7 && !already.contains("streak_7") {
            unlocked.append(badge(for: "streak_7")!)
        }
        if stats.streak >= 30 && !already.contains("streak_30") {
            unlocked.append(badge(for: "streak_30")!)
        }
        if stats.drillsCompleted >= 10 && !already.contains("drills_10") {
            unlocked.append(badge(for: "drills_10")!)
        }
        if stats.drillsCompleted >= 50 && !already.contains("drills_50") {
            unlocked.append(badge(for: "drills_50")!)
        }
        if latestScore >= 90 && !already.contains("perfect_score") {
            unlocked.append(badge(for: "perfect_score")!)
        }
        if latestFillerCount == 0 && stats.drillsCompleted >= 1 && !already.contains("no_fillers") {
            unlocked.append(badge(for: "no_fillers")!)
        }
        if stats.level >= 5 && !already.contains("level_5") {
            unlocked.append(badge(for: "level_5")!)
        }
        if stats.level >= 10 && !already.contains("level_10") {
            unlocked.append(badge(for: "level_10")!)
        }
        return unlocked
    }
}
