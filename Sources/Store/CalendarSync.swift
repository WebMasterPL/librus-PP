import Foundation
import EventKit
import UIKit

/// Mirrors Librus "Terminarz" entries into the system Calendar.
///
/// Everything lands in a dedicated calendar (`calendarTitle`) so the user can hide
/// or delete the whole lot in one gesture and we never touch their own events.
/// Each event carries `librus-event://<id>` in its `url` — that is the key the
/// upsert matches on, so re-syncing edits in place instead of piling up duplicates,
/// and entries that disappeared from Librus get cleaned up.
enum CalendarSync {
    static let enabledKey = "syncEventsToCalendar"
    static let calendarTitle = "Librus Plus"
    private static let urlScheme = "librus-event://"

    /// How far around today we keep the mirror in sync.
    private static let pastDays = -7
    private static let futureDays = 365

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    enum SyncResult {
        case synced(added: Int, updated: Int, removed: Int)
        /// Calendar access was never granted, or was revoked in Settings.
        case denied
        case failed(String)
    }

    // MARK: - Access

    static var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// Full (not write-only) access is required: the upsert has to read back what it
    /// previously wrote to update and prune it.
    static func requestAccess() async -> Bool {
        do { return try await EKEventStore().requestFullAccessToEvents() }
        catch { return false }
    }

    // MARK: - Sync

    @discardableResult
    static func sync(events items: [CalendarEvent], bellSchedule: [BellPeriod]) async -> SyncResult {
        guard isAuthorized else { return .denied }

        let store = EKEventStore()
        do {
            let calendar = try mirrorCalendar(in: store)
            let from = LibrusDate.addDays(pastDays, to: LibrusDate.today)
            let to = LibrusDate.addDays(futureDays, to: LibrusDate.today)

            // Only events we planted carry the URL key; anything else in this
            // calendar was put there by the user and is left alone.
            let existing = store.events(
                matching: store.predicateForEvents(withStart: from, end: to, calendars: [calendar])
            )
            var mine: [Int: EKEvent] = [:]
            for event in existing {
                if let id = librusID(from: event.url) { mine[id] = event }
            }

            let wanted = items.filter { item in
                guard let date = item.date else { return false }
                return date >= from && date <= to
            }

            var added = 0, updated = 0, removed = 0

            for item in wanted {
                if let event = mine.removeValue(forKey: item.id) {
                    let before = signature(of: event)
                    apply(item, to: event, in: calendar, bellSchedule: bellSchedule)
                    if signature(of: event) != before {
                        try store.save(event, span: .thisEvent, commit: false)
                        updated += 1
                    }
                } else {
                    let event = EKEvent(eventStore: store)
                    apply(item, to: event, in: calendar, bellSchedule: bellSchedule)
                    try store.save(event, span: .thisEvent, commit: false)
                    added += 1
                }
            }

            // Left over = the Librus entry behind it is gone.
            for stale in mine.values {
                try store.remove(stale, span: .thisEvent, commit: false)
                removed += 1
            }

            try store.commit()
            return .synced(added: added, updated: updated, removed: removed)
        } catch {
            store.reset()
            return .failed(error.localizedDescription)
        }
    }

    /// Drops the whole mirror calendar — used when the user switches the option off.
    static func removeMirrorCalendar() {
        guard isAuthorized else { return }
        let store = EKEventStore()
        guard let calendar = store.calendars(for: .event)
            .first(where: { $0.title == calendarTitle && $0.allowsContentModifications })
        else { return }
        try? store.removeCalendar(calendar, commit: true)
    }

    // MARK: - Calendar

    private static func mirrorCalendar(in store: EKEventStore) throws -> EKCalendar {
        if let existing = store.calendars(for: .event)
            .first(where: { $0.title == calendarTitle && $0.allowsContentModifications }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = calendarTitle
        calendar.cgColor = UIColor(red: 0.043, green: 0.505, blue: 0.545, alpha: 1).cgColor
        // A local source keeps the mirror off the user's iCloud unless that's the
        // only thing available — this is derived data, not something to sync around.
        calendar.source = store.sources.first { $0.sourceType == .local }
            ?? store.defaultCalendarForNewEvents?.source
            ?? store.sources.first
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    // MARK: - Mapping

    private static func apply(
        _ item: CalendarEvent, to event: EKEvent, in calendar: EKCalendar, bellSchedule: [BellPeriod]
    ) {
        event.calendar = calendar
        event.title = title(for: item)
        event.notes = notes(for: item)
        event.url = URL(string: "\(urlScheme)\(item.id)")

        let day = item.date ?? LibrusDate.today
        let span = span(for: item, on: day, bellSchedule: bellSchedule)
        event.startDate = span.start
        event.endDate = span.end
        event.isAllDay = span.allDay
    }

    private static func title(for item: CalendarEvent) -> String {
        let body = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return item.category ?? item.subject ?? "Wpis z Librusa" }
        if let subject = item.subject, !subject.isEmpty { return "\(subject): \(body)" }
        return body
    }

    private static func notes(for item: CalendarEvent) -> String {
        var lines: [String] = []
        if let category = item.category { lines.append("Kategoria: \(category)") }
        if let subject = item.subject { lines.append("Przedmiot: \(subject)") }
        if let teacher = item.teacher { lines.append("Nauczyciel: \(teacher)") }
        if let lesson = item.lessonNo { lines.append("Lekcja: \(lesson)") }
        lines.append("Dodane automatycznie z terminarza Librusa.")
        return lines.joined(separator: "\n")
    }

    /// Prefers the bell schedule (exact lesson slot), then an explicit time, and
    /// falls back to an all-day entry when Librus gives neither.
    private static func span(
        for item: CalendarEvent, on day: Date, bellSchedule: [BellPeriod]
    ) -> (start: Date, end: Date, allDay: Bool) {
        let calendar = LibrusDate.calendar
        let midnight = calendar.startOfDay(for: day)

        if let no = item.lessonNo,
           let period = bellSchedule.first(where: { $0.number == no }),
           let from = LibrusDate.minutesOfDay(period.start),
           let to = LibrusDate.minutesOfDay(period.end), to > from {
            return (midnight.addingTimeInterval(TimeInterval(from * 60)),
                    midnight.addingTimeInterval(TimeInterval(to * 60)), false)
        }

        if let time = item.time, let from = LibrusDate.minutesOfDay(time) {
            return (midnight.addingTimeInterval(TimeInterval(from * 60)),
                    midnight.addingTimeInterval(TimeInterval((from + 45) * 60)), false)
        }

        let end = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: midnight) ?? midnight
        return (midnight, end, true)
    }

    private static func librusID(from url: URL?) -> Int? {
        guard let string = url?.absoluteString, string.hasPrefix(urlScheme) else { return nil }
        return Int(string.dropFirst(urlScheme.count))
    }

    /// Cheap change detector so an unchanged entry isn't re-saved on every refresh.
    private static func signature(of event: EKEvent) -> String {
        let start = event.startDate?.timeIntervalSince1970 ?? 0
        let end = event.endDate?.timeIntervalSince1970 ?? 0
        return "\(event.title ?? "")|\(event.notes ?? "")|\(start)|\(end)|\(event.isAllDay)"
    }
}
