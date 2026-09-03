import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var app

    @State private var login = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case login, password }

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()

            VStack(spacing: Theme.Space.md) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .cardShadow(true)
                Text("Mój Librus")
                    .font(.largeTitle.weight(.bold))
                Text("Zaloguj się Kontem LIBRUS")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: Theme.Space.md) {
                fieldRow(icon: "envelope.fill") {
                    TextField("E-mail Konta LIBRUS", text: $login)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .login)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                fieldRow(icon: "lock.fill") {
                    SecureField("Hasło", text: $password)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(attemptLogin)
                }
            }

            if let error = app.loginError {
                ErrorBanner(message: error)
            }

            Button(action: attemptLogin) {
                Group {
                    if app.isLoggingIn {
                        ProgressView().tint(.white)
                    } else {
                        Text("Zaloguj").fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(login.isEmpty || password.isEmpty || app.isLoggingIn)

            Text("Te same dane co w oficjalnej apce Librus / na konto.librus.pl. Sam login szkolny (1234567u) nie zadziała. Dane trzymane wyłącznie w Keychainie tego urządzenia.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()
        }
        .padding(Theme.Space.xl)
        .screenBackground()
        .onAppear { focus = .login }
        .animation(Theme.Motion.standard, value: app.loginError)
    }

    private func fieldRow<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            content()
        }
        .padding(Theme.Space.md)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Color.appHairline.opacity(0.6), lineWidth: 0.5)
        )
    }

    private func attemptLogin() {
        guard !login.isEmpty, !password.isEmpty else { return }
        focus = nil
        Haptics.tap()
        Task { await app.logIn(login: login, password: password) }
    }
}
