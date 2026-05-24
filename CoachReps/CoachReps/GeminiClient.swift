import Foundation

struct CoachingAnalysis: Codable {
    let headline: String          // "Tu vas trop vite. Marc respire."
    let score: Int                // 0-100
    let analysis: String          // 2-3 sentences
    let improvements: [String]    // 2-3 actionables
    let strengths: [String]       // 1-2 positives
    let benchmark: Benchmark      // target metrics

    struct Benchmark: Codable {
        let wpm: Int
        let pauseBeforeKeyword: Double  // seconds
        let fillerMax: Int
        let pitchVariationMin: Double   // semitones
    }
}

actor GeminiClient {
    static let shared = GeminiClient()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 45
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    func analyze(drill: Drill, metrics: VoiceMetrics, transcript: String) async throws -> CoachingAnalysis {
        let prompt = Self.buildPrompt(drill: drill, metrics: metrics, transcript: transcript)

        guard let url = URL(string: APIConfig.geminiURL) else {
            throw FirestoreError.invalidURL
        }

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "headline": ["type": "STRING"],
                        "score": ["type": "INTEGER"],
                        "analysis": ["type": "STRING"],
                        "improvements": ["type": "ARRAY", "items": ["type": "STRING"]],
                        "strengths": ["type": "ARRAY", "items": ["type": "STRING"]],
                        "benchmark": [
                            "type": "OBJECT",
                            "properties": [
                                "wpm": ["type": "INTEGER"],
                                "pauseBeforeKeyword": ["type": "NUMBER"],
                                "fillerMax": ["type": "INTEGER"],
                                "pitchVariationMin": ["type": "NUMBER"]
                            ],
                            "required": ["wpm", "pauseBeforeKeyword", "fillerMax", "pitchVariationMin"]
                        ]
                    ],
                    "required": ["headline", "score", "analysis", "improvements", "strengths", "benchmark"]
                ]
            ]
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let s = String(data: data, encoding: .utf8) ?? ""
            throw FirestoreError.httpError((resp as? HTTPURLResponse)?.statusCode ?? 0, s)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            throw FirestoreError.decodingError("Unexpected Gemini response")
        }

        return try JSONDecoder().decode(CoachingAnalysis.self, from: jsonData)
    }

    private static func buildPrompt(drill: Drill, metrics: VoiceMetrics, transcript: String) -> String {
        let typeLabel: String = {
            switch drill.type {
            case .objection: return "client objection"
            case .redo: return "moment to redo"
            case .pattern: return "pattern drill"
            }
        }()

        // If this drill carries a rich coaching rubric (e.g. from a Library marker), inject it.
        let rubricBlock: String
        if let r = drill.coachingRubric, !r.isEmpty {
            rubricBlock = """

        COACHING RUBRIC (this is the methodology the rep is practicing — score against THIS, not generic objection-handling)
        \(r)
        """
        } else {
            rubricBlock = ""
        }

        return """
        You are an expert sales coach analyzing the vocal delivery of a sales rep on a \(typeLabel).

        DRILL CONTEXT
        Type: \(drill.type.rawValue)
        Title: \(drill.title)
        Situation: \(drill.context)
        Prompt: "\(drill.clientLine)"
        \(rubricBlock)

        SALES REP RESPONSE (raw transcription, may contain errors)
        "\(transcript)"

        MEASURED VOICE METRICS
        - Pace: \(metrics.wpm) words/minute (ideal for sales: 130-160 wpm)
        - Filler words detected: \(metrics.fillerCount) (found: \(metrics.fillerWordsFound.joined(separator: ", ")))
        - Pauses (≥ 0.5s): \(metrics.pauseCount)
        - Pitch variation: \(String(format: "%.1f", metrics.pitchVariation)) semitones (ideal: > 3.0)
        - Total duration: \(String(format: "%.1f", metrics.durationSec))s
        - Weak language detected: \(metrics.weakPhrasesFound.joined(separator: ", "))

        TASK
        Return a coaching analysis as JSON. Use the same language as the rubric/prompt above (if it's in French, answer in French). Direct and challenging tone — think Patrick Bet-David / Jordan Belfort, not LinkedIn.
        - headline: 1 punchy sentence summing up the main gap
        - score: overall score out of 100, judged against the rubric (if a rubric is given) — otherwise general delivery quality
        - analysis: 2-3 concrete sentences on what went wrong AND why
        - improvements: 2-3 specific actions for next time (imperative, short)
        - strengths: 1-2 things done well (don't destroy them)
        - benchmark: target metrics to hit for this type of moment

        Be tough but fair. No fluff. No "good try".
        """
    }
}
