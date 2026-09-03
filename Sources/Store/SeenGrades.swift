import Foundation

/// File-backed set of grade ids the user has already been shown (in the list or a
/// notification). Shared by `DataRepository` (foreground) and `BackgroundRefresh`.
enum SeenGrades {
    private struct Store: Codable {
        var ids: [Int]
        var hasBaseline: Bool
    }

    private static let name = "seen_grades"

    private static func load() -> Store {
        Cache.load(Store.self, from: name) ?? Store(ids: [], hasBaseline: false)
    }

    private static func save(_ store: Store) {
        Cache.save(store, as: name)
    }

    static var ids: Set<Int> { Set(load().ids) }

    /// True once we've recorded a first full set — before that, "new" is meaningless.
    static var hasBaseline: Bool { load().hasBaseline }

    /// First sync: everything currently present counts as already seen.
    static func establishBaseline(_ all: Set<Int>) {
        save(Store(ids: Array(all), hasBaseline: true))
    }

    static func merge(_ more: Set<Int>) {
        var store = load()
        store.ids = Array(Set(store.ids).union(more))
        store.hasBaseline = true
        save(store)
    }

    static func newIDs(in all: Set<Int>) -> Set<Int> {
        let store = load()
        guard store.hasBaseline else { return [] }
        return all.subtracting(store.ids)
    }

    static func reset() {
        Cache.save(Store(ids: [], hasBaseline: false), as: name)
    }
}
