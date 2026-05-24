import Foundation

struct ExtractedDrill: Codable, Hashable {
    let title: String
    let context: String
    let clientLine: String
    let type: String  // "objection" | "redo" | "pattern"
}

actor CallIngestionService {
    static let shared = CallIngestionService()

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 120
        return URLSession(configuration: cfg)
    }()

    /// Send a transcript to Gemini and extract 3-5 drillable client moments.
    func extractDrills(from transcript: String) async throws -> [ExtractedDrill] {
        let prompt = """
        You are a sales coach. Below is a transcript from a real sales call. Extract 3 to 5 of the MOST coachable client moments where the rep had to handle something tough — objections, hesitations, requests for discount, "we'll think about it", competitor mentions, etc.

        For each, return:
        - title: 3-6 word label (e.g. "Discount request", "Competitor objection")
        - context: short situation tag (e.g. "Mid-call · price discussion")
        - clientLine: the actual client quote, cleaned up to 1-2 sentences. Must be from the client, not the rep.
        - type: one of "objection" (objection to handle), "redo" (a moment the rep should redo better), "pattern" (a recurring pattern to fix)

        Avoid duplicates. Avoid generic small-talk. Pick the moments a sales coach would replay.

        TRANSCRIPT:
        \(transcript.prefix(8000))
        """

        guard let url = URL(string: APIConfig.geminiURL) else {
            throw FirestoreError.invalidURL
        }
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.3,
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "title": ["type": "STRING"],
                            "context": ["type": "STRING"],
                            "clientLine": ["type": "STRING"],
                            "type": ["type": "STRING", "enum": ["objection", "redo", "pattern"]]
                        ],
                        "required": ["title", "context", "clientLine", "type"]
                    ]
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
            throw FirestoreError.decodingError("Unexpected Gemini extraction response")
        }
        return try JSONDecoder().decode([ExtractedDrill].self, from: jsonData)
    }
}
