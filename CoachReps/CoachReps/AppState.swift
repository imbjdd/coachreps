import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    // Identity
    @AppStorage("user_id") private var storedUserID: String = ""
    @AppStorage("display_name") var displayName: String = ""
    @AppStorage("onboarded") var onboarded: Bool = false
    @AppStorage("reminder_enabled") var reminderEnabled: Bool = false
    @AppStorage("reminder_hour") var reminderHour: Int = 9
    @AppStorage("reminder_minute") var reminderMinute: Int = 0
    @AppStorage("team_code") var teamCode: String = ""

    var userID: String {
        if storedUserID.isEmpty {
            storedUserID = UUID().uuidString
        }
        return storedUserID
    }

    var initial: String {
        guard let c = displayName.trimmingCharacters(in: .whitespaces).first else { return "?" }
        return String(c).uppercased()
    }

    // Loaded data
    @Published var drills: [Drill] = []
    @Published var sessions: [DrillSession] = []
    @Published var teamSessions: [TeamSession] = []
    @Published var categories: [CallCategory] = []
    @Published var meetings: [Meeting] = []
    @Published var stats: UserStatsDTO = UserStatsDTO(
        totalXP: 0, level: 1, streak: 0, drillsCompleted: 0,
        lastDrillDate: "", unlockedBadges: []
    )

    // UI state
    @Published var isLoading = false
    @Published var loadError: String?
    @Published var newlyUnlockedBadges: [Badge] = []
    @Published var xpGainedAnimation: Int = 0
    @Published var leveledUp: Int? = nil  // new level if just leveled
    @Published var streakFreezeUsedAnimation: Bool = false

    // Derived
    var todayDrill: Drill? {
        guard !drills.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let objections = drills.filter { $0.type == .objection }
        let pool = objections.isEmpty ? drills : objections
        return pool[day % pool.count]
    }

    var hasCompletedDailyToday: Bool {
        guard let daily = todayDrill else { return false }
        let cal = Calendar.current
        return sessions.contains { $0.drillId == daily.id && cal.isDateInToday($0.completedAt) }
    }

    /// A different drill to suggest after daily is done.
    var bonusDrill: Drill? {
        guard !drills.isEmpty else { return nil }
        let dailyID = todayDrill?.id
        let doneTodayIDs = Set(sessions.filter { Calendar.current.isDateInToday($0.completedAt) }.map { $0.drillId })
        let candidates = drills.filter { $0.id != dailyID && !doneTodayIDs.contains($0.id) }
        if let c = candidates.randomElement() { return c }
        return drills.first { $0.id != dailyID }
    }

    /// Drill IDs completed today (for marking in lists).
    var drillsCompletedToday: Set<String> {
        let cal = Calendar.current
        return Set(sessions.filter { cal.isDateInToday($0.completedAt) }.map { $0.drillId })
    }

    var recentDrills: [Drill] {
        let doneIDs = Set(sessions.prefix(3).map { $0.drillId })
        let candidates = drills.filter { !doneIDs.contains($0.id) }
        return Array((candidates.isEmpty ? drills : candidates).shuffled().prefix(3))
    }

    // Team derived

    var teamMembers: [String] {
        Array(Set(teamSessions.map { $0.userName })).sorted()
    }

    /// Top performer for a specific drill (across team), excluding the current user.
    func topPerformer(forDrillId drillId: String) -> TeamSession? {
        teamSessions
            .filter { $0.drillId == drillId && $0.userId != userID }
            .max { $0.score < $1.score }
    }

    /// Best overall team score (across all drills).
    var teamLeaderboard: [(name: String, totalXP: Int, drills: Int, avgScore: Int)] {
        let grouped = Dictionary(grouping: teamSessions, by: { $0.userName })
        return grouped.map { name, sessions in
            let xp = sessions.map { $0.xp }.reduce(0, +)
            let avg = sessions.isEmpty ? 0 : sessions.map { $0.score }.reduce(0, +) / sessions.count
            return (name, xp, sessions.count, avg)
        }
        .sorted { $0.totalXP > $1.totalXP }
    }

    var weeklyWPM: Int? {
        let weekAgo = Date().addingTimeInterval(-7 * 86400)
        let recent = sessions.filter { $0.completedAt > weekAgo }
        guard !recent.isEmpty else { return nil }
        let avg = recent.map { $0.wpm }.reduce(0, +) / recent.count
        return avg
    }

    var evolutionPoints: [Double] {
        // Last 14 sessions, wpm
        Array(sessions.prefix(14).reversed().map { Double($0.wpm) })
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let drillsTask = FirestoreClient.shared.fetchDrills()
            async let customTask = FirestoreClient.shared.fetchCustomDrills(userID: userID)
            async let sessionsTask = FirestoreClient.shared.fetchSessions(userID: userID)
            async let statsTask = FirestoreClient.shared.fetchUserStats(userID: userID)
            async let categoriesTask = FirestoreClient.shared.fetchCategories()
            async let meetingsTask = FirestoreClient.shared.fetchMeetings()

            let (loadedDrills, customDrills, loadedSessions, loadedStats, loadedCategories, loadedMeetings) =
                try await (drillsTask, customTask, sessionsTask, statsTask, categoriesTask, meetingsTask)

            self.drills = customDrills.sorted { $0.date > $1.date } + loadedDrills.sorted { $0.title < $1.title }
            self.sessions = loadedSessions
            self.categories = loadedCategories
            self.meetings = loadedMeetings
            if let loadedStats {
                self.stats = loadedStats
            } else {
                try await FirestoreClient.shared.saveUserStats(userID: userID, stats: stats)
            }
        } catch {
            self.loadError = "Couldn't load drills. Check your connection."
            print("Bootstrap error: \(error)")
        }
        await refreshTeam()
    }

    /// Ingest a call: transcribe audio file, extract drills via Gemini, save each as a custom drill.
    /// Returns the count of drills created.
    func ingestCall(audioURL: URL) async throws -> Int {
        let transcript = try await SpeechTranscriber.shared.transcribe(url: audioURL, onDevice: true)
        guard !transcript.isEmpty else {
            throw FirestoreError.decodingError("Empty transcript")
        }
        let extracted = try await CallIngestionService.shared.extractDrills(from: transcript)
        var created = 0
        var newDrills: [Drill] = []
        for ext in extracted {
            let d = Drill(
                id: UUID().uuidString,
                type: DrillType.from(rawString: ext.type),
                title: ext.title,
                context: ext.context,
                clientLine: ext.clientLine,
                audioDuration: 10,
                date: Date(),
                isCustom: true
            )
            do {
                try await FirestoreClient.shared.saveCustomDrill(userID: userID, drill: d, sourceTranscript: transcript)
                newDrills.append(d)
                created += 1
            } catch {
                print("Save custom drill failed: \(error)")
            }
        }
        // Prepend new drills locally
        self.drills = newDrills + self.drills
        return created
    }

    func deleteCustomDrill(_ drill: Drill) async {
        guard drill.isCustom else { return }
        try? await FirestoreClient.shared.deleteCustomDrill(userID: userID, drillID: drill.id)
        self.drills.removeAll { $0.id == drill.id }
    }

    func refreshTeam() async {
        guard !teamCode.isEmpty else {
            self.teamSessions = []
            return
        }
        do {
            self.teamSessions = try await FirestoreClient.shared.fetchTeamSessions(teamCode: teamCode)
        } catch {
            print("Team refresh error: \(error)")
        }
    }

    // MARK: - Drill completion pipeline

    /// Returns the saved session if successful.
    func completeDrill(
        drill: Drill,
        audioURL: URL,
        pitchLog: [Double],
        pauseCount: Int
    ) async throws -> (session: DrillSession, analysis: CoachingAnalysis) {
        // 1. Transcribe
        let transcript = (try? await SpeechTranscriber.shared.transcribe(url: audioURL)) ?? ""

        // 2. Compute local metrics
        let metrics = AudioMetricsAnalyzer.metrics(
            transcript: transcript,
            audioURL: audioURL,
            pitchLog: pitchLog,
            pauseCount: pauseCount
        )

        // 3. AI analysis
        let analysis = try await GeminiClient.shared.analyze(
            drill: drill,
            metrics: metrics,
            transcript: transcript
        )

        // 4. Award XP
        let xp = GameSystem.xpAwarded(forScore: analysis.score)

        // 5. Build session
        let session = DrillSession(
            id: UUID().uuidString,
            drillId: drill.id,
            drillTitle: drill.title,
            drillType: drill.type.storageKey,
            transcript: transcript,
            wpm: metrics.wpm,
            fillerCount: metrics.fillerCount,
            pauseCount: metrics.pauseCount,
            pitchVariation: metrics.pitchVariation,
            durationSec: metrics.durationSec,
            score: analysis.score,
            xp: xp,
            analysis: analysis.analysis,
            improvements: analysis.improvements,
            completedAt: Date()
        )

        // 6. Update stats
        let previousLevel = stats.level
        let today = isoDay(Date())
        var newStats = stats
        newStats.totalXP += xp
        newStats.drillsCompleted += 1
        newStats.level = GameSystem.level(forTotalXP: newStats.totalXP)
        if newStats.lastDrillDate != today {
            if let last = isoDate(newStats.lastDrillDate),
               let diff = Calendar.current.dateComponents([.day], from: last, to: Date()).day {
                if diff == 1 {
                    newStats.streak += 1
                } else if diff == 2 {
                    // missed 1 day — try to use a streak freeze (max 1 per ISO week)
                    let currentWeek = isoWeek(Date())
                    if newStats.lastFreezeDate != currentWeek {
                        newStats.streak += 1
                        newStats.lastFreezeDate = currentWeek
                        self.streakFreezeUsedAnimation = true
                    } else {
                        newStats.streak = 1
                    }
                } else {
                    newStats.streak = 1
                }
            } else if newStats.lastDrillDate.isEmpty {
                newStats.streak = 1
            } else {
                newStats.streak = 1
            }
            newStats.lastDrillDate = today
        }

        // 7. Check badges
        let newBadges = GameSystem.newlyUnlocked(
            stats: newStats,
            latestScore: analysis.score,
            latestFillerCount: metrics.fillerCount
        )
        if !newBadges.isEmpty {
            newStats.unlockedBadges.append(contentsOf: newBadges.map { $0.id })
        }

        // 8. Save to Firestore
        try await FirestoreClient.shared.saveSession(userID: userID, session: session)
        try await FirestoreClient.shared.saveUserStats(userID: userID, stats: newStats)

        // 8b. Mirror to team if joined
        if !teamCode.isEmpty {
            try? await FirestoreClient.shared.saveTeamSession(
                teamCode: teamCode,
                userID: userID,
                displayName: displayName,
                session: session
            )
            await refreshTeam()
        }

        // 9. Update local state
        self.sessions.insert(session, at: 0)
        self.stats = newStats
        self.xpGainedAnimation = xp
        if newStats.level > previousLevel {
            self.leveledUp = newStats.level
        }
        if !newBadges.isEmpty {
            self.newlyUnlockedBadges = newBadges
        }

        // 10. Cleanup audio file
        try? FileManager.default.removeItem(at: audioURL)

        return (session, analysis)
    }

    private func isoDay(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }
    private func isoDate(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: s)
    }
    private func isoWeek(_ d: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        let week = cal.component(.weekOfYear, from: d)
        let year = cal.component(.yearForWeekOfYear, from: d)
        return String(format: "%04d-W%02d", year, week)
    }

    // MARK: - Reset

    func resetProgress() async {
        // Wipe local state
        self.sessions = []
        self.stats = UserStatsDTO(
            totalXP: 0, level: 1, streak: 0, drillsCompleted: 0,
            lastDrillDate: "", unlockedBadges: []
        )
        // Push the reset stats so the cloud reflects local
        try? await FirestoreClient.shared.saveUserStats(userID: userID, stats: stats)
        // Note: we leave existing /sessions docs in Firestore (won't be re-fetched until user reloads;
        // they're scoped to userID anyway). For a full wipe we'd need a list-delete-batch.
    }

    func completeOnboarding(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        onboarded = true
    }
}
