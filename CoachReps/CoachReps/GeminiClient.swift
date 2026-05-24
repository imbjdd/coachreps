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
            case .objection: return "objection client"
            case .redo: return "moment à refaire"
            case .pattern: return "drill de pattern"
            }
        }()

        // Si le drill porte un rubric riche (ex : marker Library), on l'injecte.
        let rubricBlock: String
        if let r = drill.coachingRubric, !r.isEmpty {
            rubricBlock = """

        RUBRIC DE COACHING (c'est la méthodologie que le commercial pratique — note CONTRE ÇA, pas du handle d'objection générique)
        \(r)
        """
        } else {
            rubricBlock = ""
        }

        return """
        Tu es un coach commercial expert qui analyse la livraison vocale d'un commercial sur un \(typeLabel).

        CONTEXTE DU DRILL
        Type : \(drill.type.rawValue)
        Titre : \(drill.title)
        Situation : \(drill.context)
        Prompt : "\(drill.clientLine)"
        \(rubricBlock)

        RÉPONSE DU COMMERCIAL (transcription brute, peut contenir des erreurs)
        "\(transcript)"

        MÉTRIQUES VOCALES MESURÉES
        - Débit : \(metrics.wpm) mots/minute (idéal commercial : 130-160 wpm)
        - Mots fillers détectés : \(metrics.fillerCount) (trouvés : \(metrics.fillerWordsFound.joined(separator: ", ")))
        - Pauses (≥ 0.5s) : \(metrics.pauseCount)
        - Variation tonale : \(String(format: "%.1f", metrics.pitchVariation)) demi-tons (idéal : > 3.0)
        - Durée totale : \(String(format: "%.1f", metrics.durationSec))s
        - Langage faible détecté : \(metrics.weakPhrasesFound.joined(separator: ", "))

        TÂCHE
        Renvoie une analyse de coaching en JSON, **en français**, ton direct et challengeant (style Patrick Bet-David / Jordan Belfort, pas LinkedIn).
        - headline : 1 phrase punchy résumant le problème principal (ex : "Tu vas trop vite. Respire avant le prix.")
        - score : note globale sur 100, jugée contre le rubric (s'il y en a un) sinon qualité de livraison générale
        - analysis : 2-3 phrases concrètes sur ce qui n'a pas marché ET pourquoi (en lien avec la ligne client)
        - improvements : 2-3 actions précises pour la prochaine fois (impératif, courtes)
        - strengths : 1-2 choses bien faites (pour ne pas tout démolir)
        - benchmark : métriques cibles à viser pour ce type de moment

        Sévère mais juste. Pas de blabla. Pas de "bonne tentative".
        """
    }
}
