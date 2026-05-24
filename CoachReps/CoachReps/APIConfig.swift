import Foundation

enum APIConfig {
    static let projectID = "coachreps-app"
    static let geminiAPIKey = "REDACTED_OLD_KEY"
    static let geminiModel = "gemini-2.5-flash"

    static var firestoreBaseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(projectID)/databases/(default)/documents"
    }

    static var geminiURL: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent?key=\(geminiAPIKey)"
    }
}
