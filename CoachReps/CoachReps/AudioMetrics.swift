import Foundation
import AVFoundation
import Accelerate

enum AudioMetricsAnalyzer {
    private static let fillerPatterns: [String] = [
        "euh", "euhm", "hum", "ben", "bah",
        "en fait", "du coup", "voilà",
        "genre", "tu vois", "tu sais",
        "j'veux dire", "je veux dire",
        "machin", "truc", "quoi"
    ]

    private static let weakPhrasePatterns: [String] = [
        "je pense que", "peut-être", "à peu près",
        "je suppose", "je crois", "il me semble",
        "c'est possible que", "j'imagine", "sans doute",
        "je ne suis pas sûr"
    ]

    static func metrics(transcript: String, audioURL: URL, pitchLog: [Double] = [], pauseCount: Int = 0) -> VoiceMetrics {
        let duration = durationSeconds(of: audioURL)
        let wordCount = wordCount(transcript)
        let wpm: Int = duration > 0.5 ? Int(Double(wordCount) / duration * 60.0) : 0

        let lower = " " + transcript.lowercased() + " "
        var fillersFound: [String] = []
        var fillerCount = 0
        for token in fillerPatterns {
            let occurrences = countOccurrences(of: " \(token) ", in: lower)
            if occurrences > 0 {
                fillersFound.append("\(token) (\(occurrences))")
                fillerCount += occurrences
            }
        }

        var weakFound: [String] = []
        for phrase in weakPhrasePatterns {
            if lower.contains(" \(phrase) ") {
                weakFound.append(phrase)
            }
        }

        let pitchVariation = semitoneVariation(from: pitchLog)

        return VoiceMetrics(
            wpm: wpm,
            fillerCount: fillerCount,
            fillerWordsFound: fillersFound,
            pauseCount: pauseCount,
            pitchVariation: pitchVariation,
            durationSec: duration,
            weakPhrasesFound: weakFound
        )
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
    }

    private static func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var current = haystack.startIndex
        while let range = haystack.range(of: needle, options: [.literal, .caseInsensitive], range: current..<haystack.endIndex) {
            count += 1
            current = range.upperBound
        }
        return count
    }

    static func durationSeconds(of url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        let dur = asset.duration
        return CMTimeGetSeconds(dur)
    }

    /// Convert a pitch log (Hz samples) into a variation measurement in semitones.
    /// Returns (max - min) in semitones for voiced samples only.
    static func semitoneVariation(from pitches: [Double]) -> Double {
        let voiced = pitches.filter { $0 > 60 && $0 < 500 }
        guard voiced.count > 5,
              let mn = voiced.min(), let mx = voiced.max(), mn > 0 else { return 0 }
        return 12.0 * log2(mx / mn)
    }
}

/// Lightweight pitch tracker using zero-crossing rate over short windows.
/// Not as accurate as autocorrelation/YIN but works fully on device with no extra deps.
final class PitchSampler {
    private(set) var samples: [Double] = []
    private(set) var pauseCount: Int = 0
    private var lastWasSilence = false
    private let silenceThreshold: Float = 0.005
    private let pauseFramesNeeded = 8 // ~0.4s @ 50ms windows

    private var silenceFrameRun = 0
    private let sampleRate: Double

    init(sampleRate: Double = 44100) {
        self.sampleRate = sampleRate
    }

    /// Process a chunk of mono Float32 audio (one window, e.g. 50ms = 2205 samples @ 44.1kHz).
    func process(_ buffer: UnsafePointer<Float>, count: Int) {
        guard count > 200 else { return }

        // RMS to detect silence
        var rms: Float = 0
        vDSP_rmsqv(buffer, 1, &rms, vDSP_Length(count))

        if rms < silenceThreshold {
            silenceFrameRun += 1
            if silenceFrameRun == pauseFramesNeeded {
                pauseCount += 1
            }
            lastWasSilence = true
            return
        } else {
            silenceFrameRun = 0
            lastWasSilence = false
        }

        // Zero-crossing rate → rough fundamental frequency estimate
        var zeroCrossings = 0
        var prev: Float = buffer[0]
        for i in 1..<count {
            let cur = buffer[i]
            if (prev >= 0 && cur < 0) || (prev < 0 && cur >= 0) {
                zeroCrossings += 1
            }
            prev = cur
        }
        // freq ≈ (zeroCrossings / 2) / window_duration
        let windowSec = Double(count) / sampleRate
        let freq = Double(zeroCrossings) / 2.0 / windowSec
        if freq > 60 && freq < 500 {
            samples.append(freq)
        }
    }

    func reset() {
        samples = []
        pauseCount = 0
        silenceFrameRun = 0
        lastWasSilence = false
    }
}
