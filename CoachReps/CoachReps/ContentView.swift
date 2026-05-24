import SwiftUI

struct ContentView: View {
    @EnvironmentObject var app: AppState
    @State private var tab: Tab = .home
    @State private var presentedDrill: Drill?
    @State private var showAllBadges = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showLeaderboard = false
    @State private var showImportCall = false
    @State private var presentedSession: DrillSession?
    @State private var showLevelUp: Int? = nil
    @State private var showBadges: [Badge] = []

    enum Tab { case home, library, profile }

    var body: some View {
        Group {
            if !app.onboarded {
                OnboardingView()
            } else {
                mainShell
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.onboarded)
    }

    private var mainShell: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home:
                    HomeView(
                        onOpenDrill: { drill in presentedDrill = drill }
                    )
                case .library:
                    LibraryView(
                        onOpenDrill: { drill in presentedDrill = drill },
                        onImportCall: { showImportCall = true }
                    )
                case .profile:
                    ProfileView(
                        onShowSessions: { showHistory = true },
                        onShowBadges: { showAllBadges = true },
                        onShowSettings: { showSettings = true },
                        onShowLeaderboard: { showLeaderboard = true },
                        onStartFirstDrill: {
                            tab = .home
                            if let d = app.todayDrill {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    presentedDrill = d
                                }
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())

            tabBar

            if let lvl = showLevelUp {
                LevelUpOverlay(level: lvl) {
                    withAnimation { showLevelUp = nil }
                }
                .transition(.opacity)
            }

            if !showBadges.isEmpty {
                BadgeUnlockOverlay(badges: showBadges) {
                    withAnimation { showBadges = [] }
                }
                .transition(.opacity)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .fullScreenCover(item: $presentedDrill) { drill in
            DrillView(drill: drill, onClose: { presentedDrill = nil })
                .environmentObject(app)
        }
        .sheet(isPresented: $showImportCall) {
            CallImportView(onClose: { showImportCall = false })
                .environmentObject(app)
        }
        .sheet(item: $presentedSession) { s in
            SessionDetailView(session: s, onClose: { presentedSession = nil })
                .environmentObject(app)
        }
        .environment(\.openSession, { sess in
            presentedSession = sess
        })
        .sheet(isPresented: $showAllBadges) {
            AllBadgesView(onClose: { showAllBadges = false })
                .environmentObject(app)
        }
        .sheet(isPresented: $showHistory) {
            SessionHistoryView(onClose: { showHistory = false })
                .environmentObject(app)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onClose: { showSettings = false })
                .environmentObject(app)
        }
        .sheet(isPresented: $showLeaderboard) {
            LeaderboardView(onClose: { showLeaderboard = false })
                .environmentObject(app)
        }
        .onChange(of: app.leveledUp) { newValue in
            if let lvl = newValue {
                withAnimation { showLevelUp = lvl }
                app.leveledUp = nil
            }
        }
        .onChange(of: app.newlyUnlockedBadges) { badges in
            if !badges.isEmpty {
                withAnimation { showBadges = badges }
                app.newlyUnlockedBadges = []
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(.home, icon: "house.fill", label: "Accueil")
            tabButton(.library, icon: "books.vertical.fill", label: "Drills")
            tabButton(.profile, icon: "person.fill", label: "Profil")
        }
        .padding(5)
        .background(
            Capsule()
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.06), radius: 18, y: 6)
        )
        .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
        .padding(.bottom, 20)
        .padding(.horizontal, 36)
    }

    private func tabButton(_ t: Tab, icon: String, label: String) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { tab = t } } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(tab == t ? .white : Theme.textSecondary)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(tab == t ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }
}
