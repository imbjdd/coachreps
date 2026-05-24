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
        Badge(id: "first_drill", name: "Premier drill", description: "Complète ton premier drill", icon: "checkmark.seal.fill"),
        Badge(id: "streak_3", name: "Streak de 3 jours", description: "Pratique 3 jours d'affilée", icon: "flame.fill"),
        Badge(id: "streak_7", name: "Une semaine", description: "Pratique 7 jours d'affilée", icon: "flame.circle.fill"),
        Badge(id: "streak_30", name: "Un mois", description: "Pratique 30 jours d'affilée", icon: "crown.fill"),
        Badge(id: "drills_10", name: "10 drills", description: "Complète 10 drills", icon: "10.circle.fill"),
        Badge(id: "drills_50", name: "50 drills", description: "Complète 50 drills", icon: "50.circle.fill"),
        Badge(id: "perfect_score", name: "Tireur d'élite", description: "Score 90+ sur un drill", icon: "star.circle.fill"),
        Badge(id: "no_fillers", name: "Zéro filler", description: "Drill sans un seul filler", icon: "mouth.fill"),
        Badge(id: "level_5", name: "Niveau 5", description: "Atteins le niveau 5", icon: "5.circle.fill"),
        Badge(id: "level_10", name: "Niveau 10", description: "Atteins le niveau 10", icon: "10.circle.fill"),
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
