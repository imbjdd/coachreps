import SwiftUI
import UniformTypeIdentifiers

struct CallImportView: View {
    @EnvironmentObject var app: AppState
    var onClose: () -> Void

    @State private var showFilePicker = false
    @State private var stage: Stage = .idle
    @State private var statusMessage = ""
    @State private var errorMessage: String?
    @State private var createdCount = 0

    enum Stage { case idle, transcribing, extracting, saving, done, failed }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Theme.background)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio, .mp3, UTType("public.mpeg-4-audio") ?? .audio, .wav],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { startImport(url: url) }
            case .failure(let err):
                errorMessage = err.localizedDescription
                stage = .failed
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surfaceMuted))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Import a call")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Theme.background.overlay(Rectangle().fill(Theme.border).frame(height: 1), alignment: .bottom))
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .idle:
            idleState
        case .transcribing, .extracting, .saving:
            processingState
        case .done:
            doneState
        case .failed:
            failedState
        }
    }

    private var idleState: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 20)
            ZStack {
                Circle().fill(Theme.highlightTint).frame(width: 96, height: 96)
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(Theme.highlight)
            }
            VStack(spacing: 8) {
                Text("Turn a real call into drills")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Pick an audio file (mp3, m4a, wav, max ~5 min).\nWe transcribe it on-device, then AI extracts 3-5 client moments worth drilling.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(title: "Choose audio file", icon: "doc.badge.arrow.up.fill") {
                showFilePicker = true
            }
            .padding(.horizontal, 20)
            Text("Your audio stays on your device.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
            Spacer().frame(height: 30)
        }
    }

    private var processingState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().stroke(Theme.border, lineWidth: 2).frame(width: 60, height: 60)
                ProgressView().tint(Theme.accent).scaleEffect(1.3)
            }
            VStack(spacing: 6) {
                Text(stageLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var stageLabel: String {
        switch stage {
        case .transcribing: return "Transcribing..."
        case .extracting: return "Extracting drills..."
        case .saving: return "Saving..."
        default: return ""
        }
    }

    private var doneState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Theme.success).frame(width: 70, height: 70)
                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(spacing: 8) {
                Text("\(createdCount) drill\(createdCount == 1 ? "" : "s") added")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("Find them at the top of \"Browse all drills\" — tagged CUSTOM.")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            Spacer()
            PrimaryButton(title: "Done", icon: "checkmark") {
                onClose()
            }
            .padding(.horizontal, 20)
            Spacer().frame(height: 30)
        }
    }

    private var failedState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.danger)
            VStack(spacing: 6) {
                Text("Import failed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(errorMessage ?? "Unknown error")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            Spacer()
            HStack(spacing: 10) {
                SecondaryButton(title: "Close", icon: "xmark") { onClose() }
                PrimaryButton(title: "Try again", icon: "arrow.counterclockwise") {
                    stage = .idle
                    errorMessage = nil
                }
            }
            .padding(.horizontal, 20)
            Spacer().frame(height: 30)
        }
    }

    private func startImport(url: URL) {
        Task {
            do {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

                // Copy file into temp so we can read after URL access ends
                let tmpURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("call-\(UUID().uuidString).\(url.pathExtension)")
                try? FileManager.default.removeItem(at: tmpURL)
                try FileManager.default.copyItem(at: url, to: tmpURL)

                // Auth speech if needed
                _ = await SpeechTranscriber.requestAuthorization()

                await MainActor.run {
                    stage = .transcribing
                    statusMessage = "On-device transcription (no upload)"
                }

                await MainActor.run { stage = .extracting; statusMessage = "Gemini reads the transcript" }
                let count = try await app.ingestCall(audioURL: tmpURL)

                try? FileManager.default.removeItem(at: tmpURL)

                await MainActor.run {
                    createdCount = count
                    stage = .done
                }
            } catch {
                await MainActor.run {
                    errorMessage = friendly(error)
                    stage = .failed
                }
            }
        }
    }

    private func friendly(_ e: Error) -> String {
        if let f = e as? FirestoreError {
            switch f {
            case .httpError(let code, let body):
                if code == 429 { return "Gemini quota hit. Retry in 1 min." }
                return "Error \(code): \(body.prefix(120))"
            case .decodingError(let m): return "Couldn't parse transcript: \(m.prefix(80))"
            case .invalidURL: return "Invalid URL."
            case .noData: return "No server response."
            }
        }
        return e.localizedDescription
    }
}
