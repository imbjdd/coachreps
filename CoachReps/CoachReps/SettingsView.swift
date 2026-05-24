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
        .alert("Reset all progress?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    await app.resetProgress()
                    onClose()
                }
            }
        } message: {
            Text("This will clear your XP, level, streak, and badges. Your name stays.")
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
            Text("Settings")
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
            Text("YOUR NAME")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            if editingName {
                HStack(spacing: 8) {
                    TextField("Your name", text: $newName)
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
                        Text("Edit")
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
            Text("DAILY REMINDER")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reminder")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Text(app.reminderEnabled ? "Daily at \(timeLabel)" : "Off")
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
                        Text("Time")
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
                Text("Notifications disabled in iOS Settings — enable to receive reminders.")
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
            Text("TEAM")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            if editingTeam {
                HStack(spacing: 8) {
                    TextField("Team code (e.g. ACME)", text: $newTeam)
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
                            Text(app.teamCode.isEmpty ? "Join a team" : app.teamCode)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                            Text(app.teamCode.isEmpty ? "Compare to top performer" : "\(app.teamMembers.count) teammates")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        Text(app.teamCode.isEmpty ? "Add" : "Change")
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
            Text("Anyone with the same code is on your leaderboard.")
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PROGRESS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            VStack(spacing: 8) {
                infoRow(label: "Level", value: "\(app.stats.level)")
                infoRow(label: "Total XP", value: "\(app.stats.totalXP)")
                infoRow(label: "Drills completed", value: "\(app.stats.drillsCompleted)")
                infoRow(label: "Current streak", value: "\(app.stats.streak) \(app.stats.streak == 1 ? "day" : "days")")
                infoRow(label: "Badges unlocked", value: "\(app.stats.unlockedBadges.count) / \(GameSystem.allBadges.count)")
            }

            Button { confirmReset = true } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset progress")
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
            Text("ABOUT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            VStack(spacing: 8) {
                infoRow(label: "App version", value: appVersion)
                infoRow(label: "Drills available", value: "\(app.drills.count)")
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
