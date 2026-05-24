import SwiftUI

/// A unified "scenario" item: either a daily-style drill or a meeting recreated as a scenario.
enum LibraryItem: Identifiable, Hashable {
    case drill(Drill)
    case meeting(Meeting)

    var id: String {
        switch self {
        case .drill(let d): return "drill-\(d.id)"
        case .meeting(let m): return "meeting-\(m.id)"
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject var app: AppState
    var onOpenDrill: (Drill) -> Void
    var onImportCall: () -> Void

    @State private var filter: Filter = .all
    @State private var confirmDeleteDrill: Drill?

    enum Filter: Hashable, CaseIterable {
        case all, scenarios, objection, custom, redo, pattern

        var label: String {
            switch self {
            case .all: return "Tous"
            case .scenarios: return "Scénarios de call"
            case .objection: return "Objections"
            case .custom: return "Personnalisés"
            case .redo: return "À refaire"
            case .pattern: return "Patterns"
            }
        }
    }

    private var groups: [(title: String, items: [LibraryItem])] {
        let drills = app.drills
        let meetings = app.meetings
        let doneToday = app.drillsCompletedToday

        switch filter {
        case .all:
            var out: [(String, [LibraryItem])] = []
            if !meetings.isEmpty {
                out.append(("Scénarios de call", meetings.map { LibraryItem.meeting($0) }))
            }
            let custom = drills.filter { $0.isCustom }
            if !custom.isEmpty {
                out.append(("Tes drills personnalisés", custom.map { LibraryItem.drill($0) }))
            }
            let obj = drills.filter { !$0.isCustom && $0.type == .objection }
            if !obj.isEmpty {
                out.append(("Objections", obj.map { LibraryItem.drill($0) }))
            }
            let redo = drills.filter { !$0.isCustom && $0.type == .redo }
            if !redo.isEmpty {
                out.append(("Moments à refaire", redo.map { LibraryItem.drill($0) }))
            }
            let pat = drills.filter { !$0.isCustom && $0.type == .pattern }
            if !pat.isEmpty {
                out.append(("Patterns à corriger", pat.map { LibraryItem.drill($0) }))
            }
            _ = doneToday
            return out
        case .scenarios:
            return [("Scénarios de call", meetings.map { LibraryItem.meeting($0) })]
        case .custom:
            return [("Tes drills personnalisés", drills.filter { $0.isCustom }.map { LibraryItem.drill($0) })]
        case .objection:
            return [("Objections", drills.filter { $0.type == .objection }.map { LibraryItem.drill($0) })]
        case .redo:
            return [("Moments à refaire", drills.filter { $0.type == .redo }.map { LibraryItem.drill($0) })]
        case .pattern:
            return [("Patterns à corriger", drills.filter { $0.type == .pattern }.map { LibraryItem.drill($0) })]
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            filterBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    let doneToday = app.drillsCompletedToday
                    ForEach(groups, id: \.title) { group in
                        if !group.items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(group.title.uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.2)
                                        .foregroundColor(Theme.textTertiary)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Theme.textTertiary)
                                }
                                ForEach(group.items) { item in
                                    itemView(item, doneToday: doneToday)
                                }
                            }
                        }
                    }
                    if groups.flatMap({ $0.items }).isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
        }
        .padding(.top, 6)
        .background(Theme.background)
        .refreshable { await app.bootstrap() }
        .alert("Supprimer ce drill ?", isPresented: Binding(
            get: { confirmDeleteDrill != nil },
            set: { if !$0 { confirmDeleteDrill = nil } }
        )) {
            Button("Annuler", role: .cancel) { confirmDeleteDrill = nil }
            Button("Supprimer", role: .destructive) {
                if let d = confirmDeleteDrill {
                    Task { await app.deleteCustomDrill(d) }
                }
                confirmDeleteDrill = nil
            }
        } message: {
            if let d = confirmDeleteDrill {
                Text("\u{201C}\(d.title)\u{201D} sera supprimé.")
            }
        }
    }

    @ViewBuilder
    private func itemView(_ item: LibraryItem, doneToday: Set<String>) -> some View {
        switch item {
        case .drill(let d):
            Button { onOpenDrill(d) } label: {
                DrillRow(drill: d, doneToday: doneToday.contains(d.id))
            }
            .buttonStyle(.plain)
            .contextMenu {
                if d.isCustom {
                    Button(role: .destructive) { confirmDeleteDrill = d } label: {
                        Label("Supprimer ce drill", systemImage: "trash")
                    }
                }
            }
        case .meeting(let m):
            Button { openMeetingScenario(m) } label: {
                MeetingScenarioRow(meeting: m)
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Drills")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(app.drills.count + app.meetings.count) scénarios")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Button(action: onImportCall) {
                Image(systemName: "waveform.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Filter.allCases, id: \.self) { f in
                    if shouldShow(f) {
                        filterChip(label: f.label, active: filter == f) { filter = f }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func shouldShow(_ f: Filter) -> Bool {
        switch f {
        case .scenarios: return !app.meetings.isEmpty
        case .custom: return app.drills.contains(where: { $0.isCustom })
        default: return true
        }
    }

    private func filterChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(active ? .white : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(active ? Theme.accent : Theme.surface))
                .overlay(Capsule().stroke(active ? Color.clear : Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Rien dans ce filtre")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("Essaie un autre onglet ci-dessus")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surfaceMuted))
    }

    // MARK: - Meeting → Drill conversion

    private func openMeetingScenario(_ m: Meeting) {
        let drill = Self.makeMeetingDrill(meeting: m, categories: app.categories)
        onOpenDrill(drill)
    }

    static func makeMeetingDrill(meeting m: Meeting, categories: [CallCategory]) -> Drill {
        // Pick a meaty client line from the transcript as the practice prompt
        let clientLines = m.transcript.filter {
            $0.speaker.lowercased() != "commercial" && $0.text.count > 40
        }
        let prompt = clientLines.max(by: { $0.text.count < $1.text.count })?.text
            ?? m.transcript.first(where: { $0.speaker.lowercased() != "commercial" })?.text
            ?? "Tu démarres ce call : présente-toi et fais ta découverte client."

        // Build a rich rubric from the category's markers (if known)
        let cat = categories.first { $0.name.caseInsensitiveCompare(m.category) == .orderedSame }
        let rubric: String? = cat.map { c in
            var out = "Méthodologie de vente : \(c.name)\n\n"
            out += c.markers.map {
                "## \($0.displayOrder). \($0.title)\n\($0.description)"
            }.joined(separator: "\n\n")
            return out
        }

        return Drill(
            id: "meeting-\(m.id)",
            type: .redo,
            title: m.title,
            context: "Scénario \(m.category)",
            clientLine: prompt,
            audioDuration: 15,
            date: m.createdAt,
            isCustom: false,
            coachingRubric: rubric
        )
    }
}

struct MeetingScenarioRow: View {
    let meeting: Meeting
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.highlightTint)
                    .frame(width: 40, height: 40)
                Image(systemName: "phone.bubble.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.highlight)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(meeting.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                    Text("SCÉNARIO")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundColor(Theme.highlight)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.highlight.opacity(0.12)))
                }
                Text("\(meeting.category) · \(meeting.transcript.count) lignes")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
    }
}
