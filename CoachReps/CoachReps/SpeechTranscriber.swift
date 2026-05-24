import Foundation
import Speech
import AVFoundation

enum TranscriptionError: Error {
    case notAuthorized
    case recognizerUnavailable
    case fileError
}

@MainActor
final class SpeechTranscriber {
    static let shared = SpeechTranscriber()

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(url: URL, locale: Locale = Locale(identifier: "fr-FR"), onDevice: Bool = false) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if onDevice, recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { cont in
            var done = false
            recognizer.recognitionTask(with: request) { result, error in
                if done { return }
                if let error {
                    done = true
                    cont.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    done = true
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
