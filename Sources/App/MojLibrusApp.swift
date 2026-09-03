import SwiftUI

@main
struct MojLibrusApp: App {
    @State private var appState = AppState()

    init() {
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(.accentColor)
                .task { BackgroundRefresh.scheduleIfEnabled() }
        }
    }
}
