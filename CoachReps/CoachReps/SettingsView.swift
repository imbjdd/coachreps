import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState
    var onClose: () -> Void

    @State private var editingName = false
    @State private var newName: String = ""
    @State private var confirmReset = false
    @State private var reminderTime = Date()
    @State private var notifPermission: Bool = true
    @State private var editingTeam = false
    @State private var newTeam = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    nameSection
                    reminderSection
                    teamSection
                    progressSection
                    aboutSection
                }
                .padding(20)
            }
        }
        .background(Theme.background)
        .task {
            let status = await NotificationManager.currentStatus()
            notifPermission = status == .authorized
            var comps = DateComponents()
            comps.hour = app.reminderHour
            comps.minute = app.reminderMinute
            reminderTime = Calendar.current.date(from: comps) ?? Date()
        }
        .alert("Réinitialiser toute la progression ?", isPresented: $confirmReset) {
            Button("Annuler", role: .cancel) {}
            Button("Réinitialiser", role: .destructive) {
                Task {
                    await app.resetProgress()
                    onClose()
                }
            }
        } message: {
            Text("Tes XP, ton niveau, ton streak et tes badges seront effacés. Ton nom reste.")
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
            Text("Réglages")
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

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TON NOM")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            if editingName {
                HStack(spacing: 8) {
                    TextField("Ton nom", text: $newName)
                        .font(.system(size: 15))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                    Button {
                        let t = newName.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { app.displayName = t }
                        editingName = false
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    newName = app.displayName
                    editingName = true
                } label: {
                    HStack {
                        Text(app.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Text("Modifier")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RAPPEL QUOTIDIEN")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rappel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Text(app.reminderEnabled ? "Tous les jours à \(timeLabel)" : "Désactivé")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { app.reminderEnabled },
                        set: { newValue in
                            Task { await toggleReminder(on: newValue) }
                        }
                    ))
                    .labelsHidden()
                    .tint(Theme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)

                if app.reminderEnabled {
                    Divider().padding(.horizontal, 14)
                    HStack {
                        Text("Heure")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: reminderTime) { newDate in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                app.reminderHour = comps.hour ?? 9
                                app.reminderMinute = comps.minute ?? 0
                                Task { await NotificationManager.scheduleDailyReminder(hour: app.reminderHour, minute: app.reminderMinute) }
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))

            if !notifPermission && app.reminderEnabled {
                Text("Notifications désactivées dans Réglages iOS — active-les pour recevoir les rappels.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.danger)
            }
        }
    }

    private var timeLabel: String {
        var comps = DateComponents()
        comps.hour = app.reminderHour
        comps.minute = app.reminderMinute
        let d = Calendar.current.date(from: comps) ?? Date()
        let f = DateFormatter(); f.timeStyle = .short
        return f.string(from: d)
    }

    private func toggleReminder(on: Bool) async {
        if on {
            let granted = await NotificationManager.requestAuthorization()
            notifPermission = granted
            if granted {
                app.reminderEnabled = true
                await NotificationManager.scheduleDailyReminder(hour: app.reminderHour, minute: app.reminderMinute)
            } else {
                app.reminderEnabled = false
            }
        } else {
            app.reminderEnabled = false
            NotificationManager.cancelDailyReminder()
        }
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ÉQUIPE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            if editingTeam {
                HStack(spacing: 8) {
                    TextField("Code équipe (ex : ACME)", text: $newTeam)
                        .font(.system(size: 14))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                    Button {
                        let t = newTeam.trimmingCharacters(in: .whitespaces).uppercased()
                        app.teamCode = t
                        editingTeam = false
                        Task { await app.refreshTeam() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    newTeam = app.teamCode
                    editingTeam = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.teamCode.isEmpty ? "Rejoindre une équipe" : app.teamCode)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Text(app.teamCode.isEmpty ? "Compare-toi au top performer" : "\(app.teamMembers.count) coéquipiers")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Text(app.teamCode.isEmpty ? "Ajouter" : "Changer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Text("Toute personne avec le même code apparaît sur ton classement.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROGRESSION")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            VStack(spacing: 8) {
                infoRow(label: "Niveau", value: "\(app.stats.level)")
                infoRow(label: "Total XP", value: "\(app.stats.totalXP)")
                infoRow(label: "Drills complétés", value: "\(app.stats.drillsCompleted)")
                infoRow(label: "Streak actuel", value: "\(app.stats.streak) \(app.stats.streak == 1 ? "jour" : "jours")")
                infoRow(label: "Badges débloqués", value: "\(app.stats.unlockedBadges.count) / \(GameSystem.allBadges.count)")
            }

            Button { confirmReset = true } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Réinitialiser la progression")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.danger.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("À PROPOS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            VStack(spacing: 8) {
                infoRow(label: "Version de l'app", value: appVersion)
                infoRow(label: "Drills disponibles", value: "\(app.drills.count)")
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}
