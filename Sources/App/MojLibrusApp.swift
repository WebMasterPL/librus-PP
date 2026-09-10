import SwiftUI

@main
struct MojLibrusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.accentColor)
                .task { BackgroundRefresh.scheduleIfEnabled() }
        }
    }
}
