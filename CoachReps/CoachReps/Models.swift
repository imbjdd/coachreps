import Foundation

struct Drill: Identifiable, Hashable {
    let id: String
    let type: DrillType
    let title: String
    let context: String
    let clientLine: String
    let audioDuration: TimeInterval
    let date: Date
    var isCustom: Bool = false
    /// Optional: rich coaching context (e.g. from a Marker), used to override the default Gemini rubric.
    var coachingRubric: String? = nil
}

enum DrillType: String, CaseIterable, Codable {
    case redo = "Redo this moment"
    case objection = "Daily objection"
    case pattern = "Your patterns"

    var icon: String {
        switch self {
        case .redo: return "arrow.counterclockwise"
        case .objection: return "exclamationmark.bubble"
        case .pattern: return "waveform"
        }
    }

    var shortLabel: String {
        switch self {
        case .redo: return "Redo"
        case .objection: return "Objection"
        case .pattern: return "Pattern"
        }
    }

    static func from(rawString: String) -> DrillType {
        switch rawString {
        case "objection": return .objection
        case "redo": return .redo
        case "pattern": return .pattern
        default: return .objection
        }
    }

    var storageKey: String {
        switch self {
        case .objection: return "objection"
        case .redo: return "redo"
        case .pattern: return "pattern"
        }
    }
}

struct VoiceMetrics {
    let wpm: Int
    let fillerCount: Int
    let fillerWordsFound: [String]
    let pauseCount: Int
    let pitchVariation: Double  // semitones
    let durationSec: Double
    let weakPhrasesFound: [String]
}
