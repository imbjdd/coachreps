import Foundation

struct CallCategory: Identifiable, Hashable {
    let id: String          // slug
    let name: String        // "Qualification"
    let displayOrder: Int
    var markers: [Marker]
}

struct Marker: Identifiable, Hashable {
    let id: String
    let title: String
    let displayOrder: Int
    let description: String       // full coaching text
    let shortDescription: String  // 1-2 sentence summary
}

struct Meeting: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let createdAt: Date
    let feedback: String          // markdown
    let evaluations: [MeetingEvaluation]
    let transcript: [TranscriptLine]

    /// Average grade across evaluations with a non-null grade (0..5 scale).
    var averageGrade: Double {
        let graded = evaluations.compactMap { $0.grade }
        guard !graded.isEmpty else { return 0 }
        return graded.reduce(0, +) / Double(graded.count)
    }
}

struct MeetingEvaluation: Hashable {
    let marker: String      // marker title
    let grade: Double?      // 0..5, may be nil
    let comment: String?
}

struct TranscriptLine: Hashable, Identifiable {
    var id: Int { startMs }
    let speaker: String     // "commercial" | "client"
    let startMs: Int
    let endMs: Int
    let text: String
}
