import AppIntents

/// Lets a Shortcuts Automation (e.g. "codziennie o 7:00") trigger the same
/// refresh-and-notify pass the app runs whenever it's opened. On a sideloaded
/// build iOS almost never runs the `BGTaskScheduler` background task (see
/// `BackgroundRefresh`), so this is the practical way to get grade / timetable /
/// message notifications without manually opening the app first. No extension,
/// no App Group — this runs as a normal (backgrounded) launch of the main app.
struct RefreshLibrusDataIntent: AppIntent {
    static let title: LocalizedStringResource = "Odśwież dane Librusa"
    static let description = IntentDescription(
        """
        Pobiera nowe oceny, zmiany w planie lekcji i wiadomości, i wysyła o nich \
        powiadomienia — bez otwierania aplikacji. Dodaj jako krok automatyzacji w \
        Skrótach (np. o stałej porze każdego dnia), żeby powiadomienia przychodziły \
        regularnie zamiast tylko wtedy, gdy sam otworzysz aplikację.
        """
    )
    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let session = LibrusSession()
        if await session.isLoggedIn {
            await DataRepository(session: session).refreshCore()
        }
        return .result()
    }
}

struct LibrusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshLibrusDataIntent(),
            phrases: [
                "Odśwież dane w \(.applicationName)",
                "Sprawdź nowości w \(.applicationName)",
            ],
            shortTitle: "Odśwież dane",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
