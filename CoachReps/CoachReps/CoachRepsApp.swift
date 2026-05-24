import SwiftUI

@main
struct CoachRepsApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .tint(.black)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
