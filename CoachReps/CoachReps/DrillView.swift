import SwiftUI

struct DrillView: View {
    let drill: Drill
    var onClose: () -> Void

    @EnvironmentObject var app: AppState
    @StateObject private var recorder = RecorderManager()
    @StateObject private var voice = VoicePlayer()
    @StateObject private var playback = AudioFilePlayer()
    @State private var phase: Phase = .listen
    @State private var analysis: CoachingAnalysis?
    @State private var session: DrillSession?
    @State private var analyzeError: String?
    @State private var requestedSpeechAuth = false

    enum Phase { case listen, record, preview, analyzing, results }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    contextBlock
                    Group {
                        switch phase {
                        case .listen: listenSection
                        case .record: recordSection
                        case .preview: previewSection
                        case .analyzing: analyzingSection
                        case .results: resultsSection
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 60)
            }
        }
        .background(Theme.background)
        .animation(.easeInOut(duration: 0.25), value: phase)
        .task {
            if !requestedSpeechAuth {
                requestedSpeechAuth = true
                _ = await SpeechTranscriber.requestAuthorization()
            }
        }
        .onDisappear {
            recorder.cancel()
            voice.stop()
            playback.stop()
        }
    }

    private var header: some View {
        HStack {
            Button {
                recorder.cancel()
                voice.stop()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surfaceMuted))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(drill.type.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(
            Theme.background
                .overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom)
        )
    }

    private var contextBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(drill.context.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            Text("The client says")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
            Text("\u{201C}\(drill.clientLine)\u{201D}")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listenSection: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                WaveformView(active: voice.isSpeaking, color: voice.isSpeaking ? Theme.accent : Theme.textTertiary)
                    .frame(height: 64)
                HStack {
                    Text(voice.isSpeaking ? "Playing..." : "Original clip")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("≈ 0:\(String(format: "%02d", Int(drill.audioDuration)))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .cardStyle()

            PrimaryButton(title: voice.isSpeaking ? "Stop" : "Listen to the clip", icon: voice.isSpeaking ? "stop.fill" : "play.fill") {
                voice.speak(drill.clientLine)
            }

            Button {
                voice.stop()
                phase = .record
            } label: {
                HStack(spacing: 6) {
                    Text("Skip to recording")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var recordSection: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("Your turn")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("30 seconds max")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(spacing: 16) {
                Text(formatTime(recorder.elapsed))
                    .font(.system(size: 44, weight: .light, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                LiveWaveform(levels: recorder.levels, active: recorder.isRecording)
                    .frame(height: 70)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surfaceMuted))

            Button {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.impactOccurred()
                if recorder.isRecording { recorder.stop() } else { recorder.start() }
            } label: {
                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? Theme.danger : Theme.accent)
                        .frame(width: 82, height: 82)
                        .shadow(color: (recorder.isRecording ? Theme.danger : Theme.accent).opacity(0.25), radius: 16, y: 6)
                    if recorder.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 26, height: 26)
                    } else {
                        Circle().fill(.white).frame(width: 28, height: 28)
                    }
                }
            }
            .buttonStyle(.plain)

            if recorder.elapsed > 0 && !recorder.isRecording {
                PrimaryButton(title: "Review my take", icon: "play.fill") {
                    if let url = recorder.lastRecordingURL {
                        playback.load(url: url)
                    }
                    phase = .preview
                }
            } else {
                Text(recorder.isRecording ? "Tap to stop" : "Tap to record")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private var previewSection: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Listen to your take")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Re-record if needed before sending to AI")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Button {
                        let g = UIImpactFeedbackGenerator(style: .light)
                        g.impactOccurred()
                        playback.togglePlay()
                    } label: {
                        ZStack {
                            Circle().fill(Theme.accent).frame(width: 56, height: 56)
                            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.surface)
                                Capsule()
                                    .fill(Theme.accent)
                                    .frame(width: max(4, geo.size.width * CGFloat(playback.progress)))
                            }
                        }
                        .frame(height: 6)
                        HStack {
                            Text(timeString(playback.progress * playback.duration))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(timeString(playback.duration))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.surfaceMuted))

            VStack(spacing: 10) {
                PrimaryButton(title: "Send for analysis", icon: "sparkles") {
                    playback.stop()
                    analyze()
                }
                SecondaryButton(title: "Re-record", icon: "arrow.counterclockwise") {
                    playback.stop()
                    recorder.cancel()
                    phase = .record
                }
            }
        }
    }

    private func timeString(_ s: Double) -> String {
        let total = Int(s.rounded())
        return String(format: "0:%02d", total)
    }

    private var analyzingSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().stroke(Theme.border, lineWidth: 2)
                    .frame(width: 60, height: 60)
                ProgressView().tint(Theme.accent).scaleEffect(1.2)
            }
            VStack(spacing: 6) {
                Text("Analyzing")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Transcription + AI scoring")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            if let err = analyzeError {
                VStack(spacing: 8) {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.danger)
                        .multilineTextAlignment(.center)
                    Button("Retry") { analyze() }
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var resultsSection: some View {
        VStack(spacing: 14) {
            if let a = analysis, let s = session {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        ScoreBadge(score: a.score)
                        Spacer()
                        Text("+\(s.xp) XP")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Theme.accent))
                    }
                    if app.streakFreezeUsedAnimation {
                        HStack(spacing: 6) {
                            Image(systemName: "snowflake")
                                .font(.system(size: 11, weight: .bold))
                            Text("Streak freeze used — you missed a day but kept the streak")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(red: 0.20, green: 0.55, blue: 0.80))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(red: 0.20, green: 0.55, blue: 0.80).opacity(0.10)))
                    }
                    Text(a.headline)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)

                if let top = app.topPerformer(forDrillId: drill.id) {
                    topPerformerCard(top: top, you: s)
                }

                let topRef = app.topPerformer(forDrillId: drill.id)
                let useTeam = topRef != nil
                comparisonRow(metric: "Pace",
                              you: "\(s.wpm) wpm",
                              target: useTeam ? "\(topRef!.wpm) wpm" : "\(a.benchmark.wpm) wpm",
                              targetLabel: useTeam ? topRef!.userName : "Target",
                              good: abs(s.wpm - (useTeam ? topRef!.wpm : a.benchmark.wpm)) <= 15)
                comparisonRow(metric: "Filler words",
                              you: "\(s.fillerCount)",
                              target: useTeam ? "\(topRef!.fillerCount)" : "≤ \(a.benchmark.fillerMax)",
                              targetLabel: useTeam ? topRef!.userName : "Target",
                              good: useTeam ? s.fillerCount <= topRef!.fillerCount : s.fillerCount <= a.benchmark.fillerMax)
                comparisonRow(metric: "Pauses detected",
                              you: "\(s.pauseCount)",
                              target: useTeam ? "\(topRef!.pauseCount)" : "≥ 1 strategic",
                              targetLabel: useTeam ? topRef!.userName : "Target",
                              good: useTeam ? s.pauseCount >= topRef!.pauseCount : s.pauseCount >= 1)
                comparisonRow(metric: "Pitch variation",
                              you: String(format: "%.1f", s.pitchVariation),
                              target: useTeam ? String(format: "%.1f", topRef!.pitchVariation) : String(format: "≥ %.1f", a.benchmark.pitchVariationMin),
                              targetLabel: useTeam ? topRef!.userName : "Target",
                              good: useTeam ? s.pitchVariation >= topRef!.pitchVariation : s.pitchVariation >= a.benchmark.pitchVariationMin)

                analysisCard(a)
                improvementsCard(a)
                if !s.transcript.isEmpty { transcriptCard(s.transcript) }

                HStack(spacing: 10) {
                    SecondaryButton(title: "Redo", icon: "arrow.counterclockwise") {
                        recorder.cancel()
                        analysis = nil
                        session = nil
                        phase = .record
                    }
                    PrimaryButton(title: "Done", icon: "checkmark") {
                        onClose()
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func analysisCard(_ a: CoachingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANALYSIS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            Text(a.analysis)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
                .lineSpacing(3)
            if !a.strengths.isEmpty {
                Divider().padding(.vertical, 4)
                Text("STRENGTHS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundColor(Theme.textTertiary)
                ForEach(a.strengths, id: \.self) { s in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.success)
                            .padding(.top, 3)
                        Text(s)
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surfaceMuted))
    }

    private func improvementsCard(_ a: CoachingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TO FIX")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            ForEach(Array(a.improvements.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Theme.accent))
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textPrimary)
                        .lineSpacing(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    private func transcriptCard(_ t: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT YOU SAID")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            Text("\u{201C}\(t)\u{201D}")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceMuted))
    }

    private func comparisonRow(metric: String, you: String, target: String, targetLabel: String = "Target", good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(metric)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textSecondary)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("You")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(Theme.textTertiary)
                    Text(you)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(good ? Theme.success : Theme.danger)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Theme.border).frame(width: 1, height: 30)
                    .padding(.horizontal, 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(targetLabel)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(1)
                    Text(target)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }

    private func topPerformerCard(top: TeamSession, you: DrillSession) -> some View {
        let delta = you.score - top.score
        let lead: String = {
            if delta > 0 { return "You beat \(top.userName) by \(delta) pts." }
            if delta == 0 { return "Tied with \(top.userName)." }
            return "\(top.userName) leads you by \(-delta) pts on this drill."
        }()
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.highlightTint).frame(width: 38, height: 38)
                Image(systemName: "crown.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.highlight)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("TOP PERFORMER · \(top.userName.uppercased())")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(Theme.textTertiary)
                Text(lead)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            Spacer()
            Text("\(top.score)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.highlightTint.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.highlight.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Pipeline

    private func analyze() {
        guard let audioURL = recorder.lastRecordingURL else {
            analyzeError = "No audio recorded."
            return
        }
        analyzeError = nil
        phase = .analyzing
        let pitchLog = recorder.pitchLog
        let pauseCount = recorder.pauseCount
        Task {
            do {
                let (s, a) = try await app.completeDrill(
                    drill: drill,
                    audioURL: audioURL,
                    pitchLog: pitchLog,
                    pauseCount: pauseCount
                )
                await MainActor.run {
                    self.session = s
                    self.analysis = a
                    self.phase = .results
                    let style: UINotificationFeedbackGenerator.FeedbackType = a.score >= 70 ? .success : .warning
                    UINotificationFeedbackGenerator().notificationOccurred(style)
                }
            } catch {
                await MainActor.run {
                    self.analyzeError = friendlyError(error)
                }
            }
        }
    }

    private func friendlyError(_ e: Error) -> String {
        if let f = e as? FirestoreError {
            switch f {
            case .httpError(let code, let body):
                if code == 429 { return "Gemini quota hit. Retry in 1 min." }
                return "Error \(code): \(body.prefix(120))"
            case .invalidURL: return "Invalid URL."
            case .decodingError(let m): return "Bad AI response: \(m.prefix(80))"
            case .noData: return "No server response."
            }
        }
        return "Error: \(e.localizedDescription)"
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let total = Int(t)
        let s = total % 60
        let tenths = Int((t - Double(total)) * 10)
        return String(format: "0:%02d.%d", s, tenths)
    }
}

struct LiveWaveform: View {
    let levels: [CGFloat]
    let active: Bool

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, l in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(active ? Theme.accent : Theme.textTertiary)
                        .frame(width: 3, height: max(6, geo.size.height * l))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ScoreBadge: View {
    let score: Int
    var color: Color {
        if score >= 80 { return Theme.success }
        if score >= 60 { return Theme.warning }
        return Theme.danger
    }
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 11))
            Text("\(score)/100")
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}
