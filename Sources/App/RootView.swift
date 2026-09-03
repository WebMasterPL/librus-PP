import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            switch app.phase {
            case .loading:
                LaunchView()
                    .transition(.opacity)
            case .loggedOut:
                LoginView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .loggedIn:
                if let repo = app.repository {
                    MainTabView()
                        .environment(repo)
                        .transition(.opacity)
                } else {
                    LaunchView()
                }
            }
        }
        .animation(Theme.Motion.emphasized, value: app.phase)
        .task {
            if case .loading = app.phase { await app.bootstrap() }
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: Theme.Space.lg) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}
