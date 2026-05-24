import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var app: AppState
    @State private var step: Int = 0
    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                content
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Capsule()
                    .fill(i <= step ? Theme.accent : Theme.surfaceMuted)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: howItWorksStep
        default: nameStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.highlightTint)
                    .frame(width: 110, height: 110)
                Image(systemName: "waveform")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(Theme.highlight)
            }
            VStack(spacing: 10) {
                Text("Coach Reps")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("3 minutes par jour.\nDeviens un meilleur closer.")
                    .font(.system(size: 17))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            Spacer()
        }
    }

    private var howItWorksStep: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer().frame(height: 12)
            Text("Comment ça marche")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 18) {
                stepRow(num: "1", title: "Écoute un vrai moment",
                        subtitle: "Une objection client extraite d'un call.")
                stepRow(num: "2", title: "Enregistre ta réponse",
                        subtitle: "30 secondes. Parle comme en live.")
                stepRow(num: "3", title: "Reçois ton score IA",
                        subtitle: "Débit, fillers, pauses, variation tonale.")
                stepRow(num: "4", title: "Monte en niveau",
                        subtitle: "Gagne de l'XP, débloque des badges, garde ton streak.")
            }
            Spacer()
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer().frame(height: 24)
            Text("Comment on doit t'appeler ?")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("Juste ton prénom — reste sur ton appareil.")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary)

            TextField("Ton prénom", text: $name)
                .focused($nameFocused)
                .font(.system(size: 17))
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
                .submitLabel(.done)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.words)
                .onSubmit { commit() }

            Spacer()
        }
        .onAppear { nameFocused = true }
    }

    private func stepRow(num: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Theme.accent).frame(width: 32, height: 32)
                Text(num)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if step > 0 {
                Button("Retour") { withAnimation { step -= 1 } }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
            }
            Button(action: next) {
                Text(step < 2 ? "Continuer" : "C'est parti")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(canContinue ? Theme.accent : Theme.accent.opacity(0.4)))
            }
            .disabled(!canContinue)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }

    private var canContinue: Bool {
        if step == 2 {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    private func next() {
        if step < 2 {
            withAnimation { step += 1 }
        } else {
            commit()
        }
    }

    private func commit() {
        app.completeOnboarding(name: name)
    }
}
