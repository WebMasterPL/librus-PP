import Foundation

/// Generic file-backed "already shown to the user" set, keyed by a cache name.
/// Backs the new-grade / new-message / timetable-change notifications: before a
/// baseline is recorded "new" is meaningless, so the first sync just seeds it.
struct SeenItems<Element: Hashable & Codable> {
    private struct Store: Codable {
        var items: [Element]
        var hasBaseline: Bool
    }

    let name: String

    private func load() -> Store {
        Cache.load(Store.self, from: name) ?? Store(items: [], hasBaseline: false)
    }
    private func save(_ store: Store) { Cache.save(store, as: name) }

    var hasBaseline: Bool { load().hasBaseline }

    func establishBaseline(_ all: Set<Element>) {
        save(Store(items: Array(all), hasBaseline: true))
    }

    func merge(_ more: Set<Element>) {
        var store = load()
        store.items = Array(Set(store.items).union(more))
        store.hasBaseline = true
        save(store)
    }

    func newOnes(in all: Set<Element>) -> Set<Element> {
        let store = load()
        guard store.hasBaseline else { return [] }
        return all.subtracting(store.items)
    }

    func reset() { save(Store(items: [], hasBaseline: false)) }
}

enum Seen {
    static let messageIDs = SeenItems<Int>(name: "seen_message_ids")
    static let timetableChanges = SeenItems<String>(name: "seen_timetable_changes")
}
