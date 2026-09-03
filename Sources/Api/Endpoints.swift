import Foundation

/// All Librus network constants in one place.
///
/// As of 2026 the old Synergia direct login (`api.librus.pl/OAuth/Token`,
/// `grant_type=password`) is dead — it returns `unsupported_grant_type`. Login now
/// goes through the Librus Portal OAuth flow (`portal.librus.pl`), which hands back
/// per-Synergia-account bearer tokens for `api.librus.pl/2.0/`.
///
/// Constants cross-checked with `github.com/szkolny-eu/szkolny-android`.
enum Librus {
    // MARK: REST v2.0 API (data)

    static let apiBase = URL(string: "https://api.librus.pl/2.0")!
    static let userAgent =
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36"

    // MARK: Portal OAuth

    /// OAuth client of the Librus "Synergia Dru2" mobile app.
    static let portalClientID = "VaItV6oRutdo8fnjJwysnTjVlvaswf52ZqmXsJGP"
    static let portalRedirectURI = "app://librus"
    /// Sent as `X-Requested-With` so the portal serves the app flow.
    static let portalRequestedWith = "pl.librus.synergiaDru2"

    static let portalAuthorizeURL = "https://portal.librus.pl/konto-librus/redirect/dru"
    static let portalLoginActionURL = "https://portal.librus.pl/konto-librus/login/action"
    static let portalTokenURL = "https://portal.librus.pl/oauth2/access_token"
    static let portalAPIBase = "https://portal.librus.pl/api"
    static let portalOrigin = "https://portal.librus.pl"

    static func synergiaAccountsURL() -> String { "\(portalAPIBase)/v3/SynergiaAccounts" }
    static func synergiaAccountFreshURL(login: String) -> String {
        "\(portalAPIBase)/v3/SynergiaAccounts/fresh/\(login)"
    }

    // MARK: Messages bridge

    static let browserUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/62.0"
    static let synergiaBase = URL(string: "https://synergia.librus.pl")!
    static let messagesModuleBase = URL(string: "https://wiadomosci.librus.pl/module")!
    static let synergiaTokenLoginPath = "/loguj/token/TOKEN/przenies"

    // MARK: REST v2.0 endpoint paths

    enum Path {
        static let me = "Me"
        static let subjects = "Subjects"
        static let users = "Users"
        static let classrooms = "Classrooms"
        static let grades = "Grades"
        static let gradeCategories = "Grades/Categories"
        static let gradeComments = "Grades/Comments"
        static let lessons = "Lessons"
        static let attendances = "Attendances"
        static let attendanceTypes = "Attendances/Types"
        static let schoolNotices = "SchoolNotices"
        static let schools = "Schools"
        static let events = "HomeWorks"
        static let eventCategories = "HomeWorks/Categories"
        static let classes = "Classes"
        static let notes = "Notes"
        static let noteCategories = "Notes/Categories"
        static let autoLoginToken = "AutoLoginToken"
        static func timetable(weekStart: String) -> String { "Timetables?weekStart=\(weekStart)" }
    }
}
