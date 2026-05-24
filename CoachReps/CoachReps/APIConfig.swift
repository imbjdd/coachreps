import Foundation

enum APIConfig {
    static let projectID = "coachreps-app"
    static let geminiModel = "gemini-2.5-flash"

    /// Loaded at runtime from Info.plist (injected from Secrets.xcconfig, not tracked in git).
    static var geminiAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GeminiAPIKey") as? String,
              !key.isEmpty, !key.contains("REPLACE") else {
            #if DEBUG
            fatalError("Missing GEMINI_API_KEY. Copy Secrets.example.xcconfig to Secrets.xcconfig and fill in the value.")
            #else
            return ""
            #endif
        }
        return key
    }

    static var firestoreBaseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"
    }

    static var geminiURL: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent?key=\(geminiAPIKey)"
    }
}
