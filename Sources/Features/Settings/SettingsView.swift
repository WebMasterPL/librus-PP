import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @Environment(DataRepository.self) private var repo

    @State private var showLogoutConfirm = false
    @State private var testNotificationMessage: String?
    @AppStorage(BackgroundRefresh.Keys.grades) private var notifyNewGrades = false
    @AppStorage(BackgroundRefresh.Keys.timetable) private var notifyTimetable = false
    @AppStorage(BackgroundRefresh.Keys.messages) private var notifyMessages = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section("Konto") {
                LabeledContent("Uczeń", value: repo.studentName.isEmpty ? "—" : repo.studentName)
                if let className = repo.schoolYear.className {
                    LabeledContent("Klasa", value: className)
                }
                if let tutor = repo.schoolYear.tutor {
                    LabeledContent("Wychowawca", value: tutor)
                }
                if let login = currentLogin {
                    LabeledContent("Login", value: login)
                }
                LabeledContent("Bieżący semestr", value: "\(repo.currentSemester)")
                if let sync = repo.lastSync {
                    LabeledContent("Ostatnia synchronizacja", value: sync.formattedPL("d MMM yyyy, HH:mm"))
                }
            }

            Section {
                Button {
                    Haptics.tap()
                    Task {
                        await repo.refreshCore()
                        await repo.loadTimetable(weekStart: LibrusDate.weekStart())
                    }
                } label: {
                    Label("Odśwież wszystko", systemImage: "arrow.clockwise")
                }
                NavigationLink {
                    DiagnosticsView()
                } label: {
                    Label("Diagnostyka połączenia", systemImage: "stethoscope")
                }
            }

            Section {
                Toggle(isOn: $notifyNewGrades) {
                    Label("Nowe oceny", systemImage: "checkmark.seal")
                }
                Toggle(isOn: $notifyTimetable) {
                    Label("Zmiany w planie lekcji", systemImage: "calendar.badge.exclamationmark")
                }
                Toggle(isOn: $notifyMessages) {
                    Label("Nowe wiadomości", systemImage: "envelope.badge")
                }
                if notifyNewGrades || notifyTimetable || notifyMessages {
                    Button {
                        Task {
                            switch await NotificationManager.sendTestNotification() {
                            case .scheduled:
                                testNotificationMessage = "Wysłane. Powiadomienie powinno pojawić się za chwilę. "
                                    + "Jeśli nie przychodzi — sprawdź Ustawienia iOS → Powiadomienia → Librus Plus. "
                                    + "W LiveContainer / sideloadzie powiadomienia często nie działają wcale."
                            case .denied:
                                testNotificationMessage = "Powiadomienia są wyłączone dla aplikacji. "
                                    + "Włącz je w Ustawieniach iOS → Powiadomienia → Librus Plus."
                            case .failed(let detail):
                                testNotificationMessage = "System odrzucił powiadomienie: \(detail)"
                            }
                        }
                    } label: {
                        Label("Wyślij powiadomienie testowe", systemImage: "paperplane")
                    }
                }
            } header: {
                Text("Powiadomienia")
            } footer: {
                Text("Eksperymentalne. iOS sam decyduje, kiedy odświeżyć aplikację w tle — dla apek sideloadowanych bywa to rzadko. Plakietki „nowe” w aplikacji działają zawsze.")
            }

            Section {
                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Label("Wyloguj się", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } footer: {
                Text("Wylogowanie usuwa dane logowania z Keychaina oraz lokalną pamięć podręczną.")
            }

            Section("O aplikacji") {
                LabeledContent("Wersja", value: version)
                LabeledContent("Widżet (App Group)", value: SharedStore.status)
                    .font(.caption)
                Link(destination: URL(string: "https://github.com/WebMasterPL/librus-PP/issues")!) {
                    Label("Zgłoś problem", systemImage: "ladybug")
                }
                Link(destination: URL(string: "https://github.com/WebMasterPL/librus-PP")!) {
                    Label("Kod źródłowy (GitHub)", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Text("""
                Nieoficjalny klient Librus Synergia — bez związku z firmą Librus. Do użytku \
                edukacyjnego / własnego, na własną odpowiedzialność. Łączy się wyłącznie z \
                *.librus.pl; dane logowania trzymane są tylko w Keychainie tego urządzenia. \
                Brak analityki i serwera pośredniczącego.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appGroupedBackground.ignoresSafeArea())
        .navigationTitle("Ustawienia")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.accentColor)
        .onChange(of: notifyNewGrades) { _, on in handleToggle(on) { notifyNewGrades = false } }
        .onChange(of: notifyTimetable) { _, on in handleToggle(on) { notifyTimetable = false } }
        .onChange(of: notifyMessages) { _, on in handleToggle(on) { notifyMessages = false } }
        .confirmationDialog("Wylogować się?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Wyloguj", role: .destructive) {
                Task { await app.logOut() }
            }
            Button("Anuluj", role: .cancel) {}
        }
        .alert("Powiadomienie testowe", isPresented: Binding(
            get: { testNotificationMessage != nil },
            set: { if !$0 { testNotificationMessage = nil } }
        ), presenting: testNotificationMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
    }

    private var currentLogin: String? {
        Credentials.load()?.login
    }

    /// Shared handler for the three notification toggles: ask for permission when
    /// switching one on (revert via `revert` if denied), (re)schedule or cancel the
    /// background task based on whether any are still on.
    private func handleToggle(_ turnedOn: Bool, revert: @escaping () -> Void) {
        Task {
            if turnedOn {
                let granted = await NotificationManager.requestAuthorization()
                if granted {
                    BackgroundRefresh.scheduleIfEnabled()
                } else {
                    revert()
                }
            } else if !BackgroundRefresh.anyEnabled {
                BackgroundRefresh.cancel()
            }
        }
    }
}
