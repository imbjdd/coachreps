import Foundation
import AVFoundation
import Combine

@MainActor
final class RecorderManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var level: CGFloat = 0
    @Published var levels: [CGFloat] = Array(repeating: 0, count: 38)
    @Published var lastRecordingURL: URL?

    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var startTime: TimeInterval = 0
    private var timer: Timer?
    private let pitchSampler = PitchSampler()

    var pitchLog: [Double] { pitchSampler.samples }
    var pauseCount: Int { pitchSampler.pauseCount }

    func requestPermission(_ done: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { done(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { done(granted) }
            }
        }
    }

    func start() {
        requestPermission { [weak self] granted in
            guard let self, granted else { return }
            self.beginRecording()
        }
    }

    private func beginRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("drill-\(UUID().uuidString).caf")

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        do {
            audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        } catch {
            return
        }

        pitchSampler.reset()
        levels = Array(repeating: 0, count: 38)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            // write to file
            try? self.audioFile?.write(from: buffer)

            // process for pitch / pauses
            if let ch = buffer.floatChannelData?[0] {
                let count = Int(buffer.frameLength)
                self.pitchSampler.process(ch, count: count)

                // RMS for waveform
                var sum: Float = 0
                for i in 0..<count { sum += ch[i] * ch[i] }
                let rms = sqrt(sum / Float(count))
                let normalized = CGFloat(min(1.0, max(0.05, rms * 8)))
                Task { @MainActor in
                    self.level = normalized
                    if !self.levels.isEmpty {
                        self.levels.removeFirst()
                        self.levels.append(normalized)
                    }
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            return
        }

        startTime = CACurrentMediaTime()
        elapsed = 0
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRecording else { return }
                self.elapsed = CACurrentMediaTime() - self.startTime
                if self.elapsed >= 30 { self.stop() }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        lastRecordingURL = audioFile?.url
        audioFile = nil
        isRecording = false
    }

    func cancel() {
        stop()
        if let url = lastRecordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        lastRecordingURL = nil
        elapsed = 0
        levels = Array(repeating: 0, count: 38)
        pitchSampler.reset()
    }
}

@MainActor
final class AudioFilePlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            player = p
            duration = p.duration
        } catch {
            player = nil
        }
    }

    func togglePlay() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
            timer?.invalidate()
        } else {
            p.play()
            isPlaying = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let p = self.player else { return }
                    self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
                }
            }
        }
    }

    func stop() {
        player?.stop()
        timer?.invalidate()
        timer = nil
        isPlaying = false
        progress = 0
    }
}

extension AudioFilePlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1
            self.timer?.invalidate()
        }
    }
}

@MainActor
final class VoicePlayer: NSObject, ObservableObject {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, language: String = "en-US") {
        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
            isSpeaking = false
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synth.speak(utterance)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension VoicePlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
