import Foundation

enum FirestoreError: Error {
    case invalidURL
    case httpError(Int, String)
    case decodingError(String)
    case noData
}

actor FirestoreClient {
    static let shared = FirestoreClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 30
        return URLSession(configuration: cfg)
    }()

    // MARK: - Drills

    func fetchDrills() async throws -> [Drill] {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/drills?pageSize=100") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else {
            return []
        }
        return docs.compactMap { Self.parseDrill($0) }
    }

    private static func parseDrill(_ doc: [String: Any]) -> Drill? {
        guard let name = doc["name"] as? String,
              let fields = doc["fields"] as? [String: Any] else { return nil }
        let id = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
        let typeStr = stringValue(fields["type"]) ?? "objection"
        let title = stringValue(fields["title"]) ?? ""
        let context = stringValue(fields["context"]) ?? ""
        let clientLine = stringValue(fields["clientLine"]) ?? ""
        let duration = TimeInterval(intValue(fields["audioDuration"]) ?? 10)
        let type: DrillType = {
            switch typeStr {
            case "objection": return .objection
            case "redo": return .redo
            case "pattern": return .pattern
            default: return .objection
            }
        }()
        return Drill(
            id: id,
            type: type,
            title: title,
            context: context,
            clientLine: clientLine,
            audioDuration: duration,
            date: Date()
        )
    }

    // MARK: - Sessions (drill attempts)

    func saveSession(userID: String, session sess: DrillSession) async throws {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/users/\(userID)/sessions/\(sess.id)") else {
            throw FirestoreError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: sess.firestoreFields)
        let (data, resp) = try await session.data(for: req)
        try check(resp, data)
    }

    func fetchSessions(userID: String) async throws -> [DrillSession] {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/users/\(userID)/sessions?pageSize=100") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else {
            return []
        }
        return docs.compactMap { Self.parseSession($0) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    private static func parseSession(_ doc: [String: Any]) -> DrillSession? {
        guard let name = doc["name"] as? String,
              let fields = doc["fields"] as? [String: Any] else { return nil }
        let id = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
        return DrillSession(
            id: id,
            drillId: stringValue(fields["drillId"]) ?? "",
            drillTitle: stringValue(fields["drillTitle"]) ?? "",
            drillType: stringValue(fields["drillType"]) ?? "objection",
            transcript: stringValue(fields["transcript"]) ?? "",
            wpm: intValue(fields["wpm"]) ?? 0,
            fillerCount: intValue(fields["fillerCount"]) ?? 0,
            pauseCount: intValue(fields["pauseCount"]) ?? 0,
            pitchVariation: doubleValue(fields["pitchVariation"]) ?? 0,
            durationSec: doubleValue(fields["durationSec"]) ?? 0,
            score: intValue(fields["score"]) ?? 0,
            xp: intValue(fields["xp"]) ?? 0,
            analysis: stringValue(fields["analysis"]) ?? "",
            improvements: stringArrayValue(fields["improvements"]) ?? [],
            completedAt: timestampValue(fields["completedAt"]) ?? Date()
        )
    }

    // MARK: - Library: Categories & Markers

    func fetchCategories() async throws -> [CallCategory] {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/categories?pageSize=50") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { return [] }
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else {
            return []
        }
        var categories: [CallCategory] = []
        for doc in docs {
            guard let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { continue }
            let id = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
            let displayName = Self.stringValue(fields["name"]) ?? id
            let displayOrder = Self.intValue(fields["displayOrder"]) ?? 99
            let markers = (try? await fetchMarkers(categoryID: id)) ?? []
            categories.append(CallCategory(
                id: id,
                name: displayName,
                displayOrder: displayOrder,
                markers: markers.sorted { $0.displayOrder < $1.displayOrder }
            ))
        }
        return categories.sorted { $0.displayOrder < $1.displayOrder }
    }

    private func fetchMarkers(categoryID: String) async throws -> [Marker] {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/categories/\(categoryID)/markers?pageSize=100") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { return [] }
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else {
            return []
        }
        return docs.compactMap { doc -> Marker? in
            guard let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return nil }
            let id = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
            return Marker(
                id: id,
                title: Self.stringValue(fields["title"]) ?? "",
                displayOrder: Self.intValue(fields["displayOrder"]) ?? 99,
                description: Self.stringValue(fields["description"]) ?? "",
                shortDescription: Self.stringValue(fields["shortDescription"]) ?? ""
            )
        }
    }

    // MARK: - Library: Meetings

    func fetchMeetings() async throws -> [Meeting] {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/meetings?pageSize=100") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { return [] }
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else {
            return []
        }
        return docs.compactMap { Self.parseMeeting($0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private static func parseMeeting(_ doc: [String: Any]) -> Meeting? {
        guard let name = doc["name"] as? String,
              let fields = doc["fields"] as? [String: Any] else { return nil }
        let id = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
        let title = stringValue(fields["title"]) ?? "Untitled"
        let category = stringValue(fields["category"]) ?? ""
        let createdAt = timestampValue(fields["createdAt"]) ?? Date()
        let feedback = stringValue(fields["feedback"]) ?? ""

        var evaluations: [MeetingEvaluation] = []
        if let evArr = (fields["evaluations"] as? [String: Any])?["arrayValue"] as? [String: Any],
           let values = evArr["values"] as? [[String: Any]] {
            for v in values {
                guard let mapValue = (v["mapValue"] as? [String: Any])?["fields"] as? [String: Any] else { continue }
                let marker = stringValue(mapValue["marker"]) ?? ""
                let comment = stringValue(mapValue["comment"])
                let grade: Double? = doubleValue(mapValue["grade"])
                evaluations.append(MeetingEvaluation(marker: marker, grade: grade, comment: comment?.isEmpty == false ? comment : nil))
            }
        }

        var transcript: [TranscriptLine] = []
        if let trArr = (fields["transcript"] as? [String: Any])?["arrayValue"] as? [String: Any],
           let values = trArr["values"] as? [[String: Any]] {
            for v in values {
                guard let mapValue = (v["mapValue"] as? [String: Any])?["fields"] as? [String: Any] else { continue }
                transcript.append(TranscriptLine(
                    speaker: stringValue(mapValue["speaker"]) ?? "?",
                    startMs: intValue(mapValue["startMs"]) ?? 0,
                    endMs: intValue(mapValue["endMs"]) ?? 0,
                    text: stringValue(mapValue["text"]) ?? ""
                ))
            }
        }

        return Meeting(
            id: id,
            title: title,
            category: category,
            createdAt: createdAt,
            feedback: feedback,
            evaluations: evaluations,
            transcript: transcript
        )
    }

    // MARK: - Team sessions (shared by team code)

    /// Mirror a user's drill session into the team's shared collection so teammates can compete.
    func saveTeamSession(teamCode: String, userID: String, displayName: String, session sess: DrillSession) async throws {
        let safeTeam = teamCode.uppercased()
        guard !safeTeam.isEmpty else { return }
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/teams/\(safeTeam)/sessions/\(sess.id)") else {
            throw FirestoreError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = sess.firestoreFields
        // augment with userID + displayName
        if var fields = body["fields"] as? [String: Any] {
            fields["userId"] = ["stringValue": userID]
            fields["userName"] = ["stringValue": displayName]
            body["fields"] = fields
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        try check(resp, data)
    }

    func fetchTeamSessions(teamCode: String) async throws -> [TeamSession] {
        let safeTeam = teamCode.uppercased()
        guard !safeTeam.isEmpty else { return [] }
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/teams/\(safeTeam)/sessions?pageSize=300") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { return [] }
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else {
            return []
        }
        return docs.compactMap { Self.parseTeamSession($0) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    private static func parseTeamSession(_ doc: [String: Any]) -> TeamSession? {
        guard let name = doc["name"] as? String,
              let fields = doc["fields"] as? [String: Any] else { return nil }
        let id = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
        return TeamSession(
            id: id,
            userId: stringValue(fields["userId"]) ?? "",
            userName: stringValue(fields["userName"]) ?? "Anon",
            drillId: stringValue(fields["drillId"]) ?? "",
            drillTitle: stringValue(fields["drillTitle"]) ?? "",
            wpm: intValue(fields["wpm"]) ?? 0,
            fillerCount: intValue(fields["fillerCount"]) ?? 0,
            pauseCount: intValue(fields["pauseCount"]) ?? 0,
            pitchVariation: doubleValue(fields["pitchVariation"]) ?? 0,
            score: intValue(fields["score"]) ?? 0,
            xp: intValue(fields["xp"]) ?? 0,
            completedAt: timestampValue(fields["completedAt"]) ?? Date()
        )
    }

    // MARK: - Custom user drills (extracted from calls)

    func saveCustomDrill(userID: String, drill: Drill, sourceTranscript: String? = nil) async throws {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/users/\(userID)/customDrills/\(drill.id)") else {
            throw FirestoreError.invalidURL
        }
        var fields: [String: Any] = [
            "type": ["stringValue": drill.type.storageKey],
            "title": ["stringValue": drill.title],
            "context": ["stringValue": drill.context],
            "clientLine": ["stringValue": drill.clientLine],
            "audioDuration": ["integerValue": String(Int(drill.audioDuration))],
            "createdAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        if let s = sourceTranscript {
            fields["sourceTranscript"] = ["stringValue": String(s.prefix(4000))]
        }
        let body: [String: Any] = ["fields": fields]

        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await session.data(for: req)
        try check(resp, data)
    }

    func fetchCustomDrills(userID: String) async throws -> [Drill] {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/users/\(userID)/customDrills?pageSize=100") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { return [] }
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else {
            return []
        }
        return docs.compactMap { doc -> Drill? in
            guard let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return nil }
            let id = name.split(separator: "/").last.map(String.init) ?? UUID().uuidString
            return Drill(
                id: id,
                type: DrillType.from(rawString: Self.stringValue(fields["type"]) ?? "objection"),
                title: Self.stringValue(fields["title"]) ?? "",
                context: Self.stringValue(fields["context"]) ?? "",
                clientLine: Self.stringValue(fields["clientLine"]) ?? "",
                audioDuration: TimeInterval(Self.intValue(fields["audioDuration"]) ?? 10),
                date: Self.timestampValue(fields["createdAt"]) ?? Date(),
                isCustom: true
            )
        }
    }

    func deleteCustomDrill(userID: String, drillID: String) async throws {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/users/\(userID)/customDrills/\(drillID)") else {
            throw FirestoreError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        let (data, resp) = try await session.data(for: req)
        try check(resp, data)
    }

    // MARK: - User profile

    func saveUserStats(userID: String, stats: UserStatsDTO) async throws {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/users/\(userID)") else {
            throw FirestoreError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: stats.firestoreFields)
        let (data, resp) = try await session.data(for: req)
        try check(resp, data)
    }

    func fetchUserStats(userID: String) async throws -> UserStatsDTO? {
        guard let url = URL(string: "\(APIConfig.firestoreBaseURL)/users/\(userID)") else {
            throw FirestoreError.invalidURL
        }
        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { return nil }
        try check(resp, data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else { return nil }
        return UserStatsDTO(
            totalXP: Self.intValue(fields["totalXP"]) ?? 0,
            level: Self.intValue(fields["level"]) ?? 1,
            streak: Self.intValue(fields["streak"]) ?? 0,
            drillsCompleted: Self.intValue(fields["drillsCompleted"]) ?? 0,
            lastDrillDate: Self.stringValue(fields["lastDrillDate"]) ?? "",
            unlockedBadges: Self.stringArrayValue(fields["unlockedBadges"]) ?? [],
            lastFreezeDate: Self.stringValue(fields["lastFreezeDate"]) ?? ""
        )
    }

    // MARK: - Helpers

    private func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { throw FirestoreError.noData }
        if !(200..<300).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw FirestoreError.httpError(http.statusCode, body)
        }
    }

    fileprivate static func stringValue(_ any: Any?) -> String? {
        (any as? [String: Any])?["stringValue"] as? String
    }
    fileprivate static func intValue(_ any: Any?) -> Int? {
        if let s = (any as? [String: Any])?["integerValue"] as? String { return Int(s) }
        if let n = (any as? [String: Any])?["integerValue"] as? Int { return n }
        return nil
    }
    fileprivate static func doubleValue(_ any: Any?) -> Double? {
        if let d = (any as? [String: Any])?["doubleValue"] as? Double { return d }
        if let s = (any as? [String: Any])?["doubleValue"] as? String { return Double(s) }
        if let i = intValue(any) { return Double(i) }
        return nil
    }
    fileprivate static func stringArrayValue(_ any: Any?) -> [String]? {
        guard let arr = (any as? [String: Any])?["arrayValue"] as? [String: Any],
              let values = arr["values"] as? [[String: Any]] else { return nil }
        return values.compactMap { $0["stringValue"] as? String }
    }
    fileprivate static func timestampValue(_ any: Any?) -> Date? {
        guard let s = (any as? [String: Any])?["timestampValue"] as? String else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

// MARK: - DTOs

struct DrillSession: Identifiable, Hashable {
    let id: String
    let drillId: String
    let drillTitle: String
    let drillType: String
    let transcript: String
    let wpm: Int
    let fillerCount: Int
    let pauseCount: Int
    let pitchVariation: Double
    let durationSec: Double
    let score: Int       // 0-100
    let xp: Int
    let analysis: String
    let improvements: [String]
    let completedAt: Date

    var firestoreFields: [String: Any] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return [
            "fields": [
                "drillId": ["stringValue": drillId],
                "drillTitle": ["stringValue": drillTitle],
                "drillType": ["stringValue": drillType],
                "transcript": ["stringValue": transcript],
                "wpm": ["integerValue": String(wpm)],
                "fillerCount": ["integerValue": String(fillerCount)],
                "pauseCount": ["integerValue": String(pauseCount)],
                "pitchVariation": ["doubleValue": pitchVariation],
                "durationSec": ["doubleValue": durationSec],
                "score": ["integerValue": String(score)],
                "xp": ["integerValue": String(xp)],
                "analysis": ["stringValue": analysis],
                "improvements": ["arrayValue": ["values": improvements.map { ["stringValue": $0] }]],
                "completedAt": ["timestampValue": iso.string(from: completedAt)]
            ]
        ]
    }
}

struct TeamSession: Identifiable, Hashable {
    let id: String
    let userId: String
    let userName: String
    let drillId: String
    let drillTitle: String
    let wpm: Int
    let fillerCount: Int
    let pauseCount: Int
    let pitchVariation: Double
    let score: Int
    let xp: Int
    let completedAt: Date
}

struct UserStatsDTO {
    var totalXP: Int
    var level: Int
    var streak: Int
    var drillsCompleted: Int
    var lastDrillDate: String
    var unlockedBadges: [String]
    var lastFreezeDate: String = ""  // ISO week marker (YYYY-WW), only 1 freeze per week

    var firestoreFields: [String: Any] {
        [
            "fields": [
                "totalXP": ["integerValue": String(totalXP)],
                "level": ["integerValue": String(level)],
                "streak": ["integerValue": String(streak)],
                "drillsCompleted": ["integerValue": String(drillsCompleted)],
                "lastDrillDate": ["stringValue": lastDrillDate],
                "lastFreezeDate": ["stringValue": lastFreezeDate],
                "unlockedBadges": ["arrayValue": ["values": unlockedBadges.map { ["stringValue": $0] }]]
            ]
        ]
    }
}
