import Foundation

/// Raw Librus timetable lessons -> display entries. Pure, so the change rules
/// (see `RawLesson`) are unit-testable against real-shaped JSON.
enum TimetableMapping {
    /// Id -> name tables for refs that arrive without an inline name (common
    /// for `Org*` / `New*`).
    struct Lookups {
        var subjectName: [Int: String] = [:]
        var teacherName: [Int: String] = [:]
        var classroomName: [Int: String] = [:]
    }

    /// One day's slots, flattened in display order. A slot can hold several
    /// lessons (groups, or a cancelled lesson plus whatever was moved into its
    /// place); each keeps its own id, and only exact duplicates are merged.
    static func entries(for slots: [[RawLesson]], date: Date, lookups: Lookups) -> [TimetableEntry] {
        var picked: [(entry: TimetableEntry, order: Int)] = []
        var seen = Set<String>()
        for (slotIndex, slot) in slots.enumerated() {
            for (itemIndex, lesson) in slot.enumerated() {
                guard let e = entry(from: lesson, date: date, idSuffix: "\(slotIndex).\(itemIndex)",
                                    lookups: lookups) else { continue }
                let key = [String(e.lessonNo), e.start, e.subject, e.teacher ?? "", e.classroom ?? "",
                           e.note ?? "", e.isCancelled ? "c" : "", e.isSubstitution ? "s" : ""]
                    .joined(separator: "|")
                guard seen.insert(key).inserted else { continue }
                picked.append((e, picked.count))
            }
        }
        // Within a lesson number, what actually takes place comes first.
        return picked.sorted { a, b in
            if a.entry.lessonNo != b.entry.lessonNo { return a.entry.lessonNo < b.entry.lessonNo }
            if a.entry.isGone != b.entry.isGone { return !a.entry.isGone }
            return a.order < b.order
        }.map { $0.entry }
    }

    static func entry(from l: RawLesson, date: Date, idSuffix: String, lookups: Lookups) -> TimetableEntry? {
        guard let no = l.lessonNo, let from = l.hourFrom, let to = l.hourTo else { return nil }

        var movedTo: LessonSlot?
        var movedFrom: LessonSlot?
        var originalTeacher: String?
        var originalSubject: String?

        if l.isSubstitution && l.isCancelled {
            if l.newDate != nil || l.newLessonNo != nil || l.newHourFrom != nil {
                movedTo = LessonSlot(date: LibrusDate.fromYMD(l.newDate) ?? date,
                                     lessonNo: l.newLessonNo, start: l.newHourFrom)
            }
        } else if l.isSubstitution {
            let orgDate = LibrusDate.fromYMD(l.orgDate) ?? date
            let sameSlot = LibrusDate.isSameDay(orgDate, date)
                && (l.orgLessonNo == nil || l.orgLessonNo == no)
            if !sameSlot {
                movedFrom = LessonSlot(date: orgDate, lessonNo: l.orgLessonNo, start: l.orgHourFrom)
            }
            if differs(l.orgTeacher?.id, l.teacher?.id,
                       person(l.orgTeacher, lookups), person(l.teacher, lookups)) {
                originalTeacher = person(l.orgTeacher, lookups)
            }
            if differs(l.orgSubject?.id, l.subject?.id,
                       named(l.orgSubject, lookups.subjectName), named(l.subject, lookups.subjectName)) {
                originalSubject = named(l.orgSubject, lookups.subjectName)
            }
        }

        let room = named(l.classroom, lookups.classroomName)
        let orgRoom = l.isSubstitution && !l.isCancelled ? named(l.orgClassroom, lookups.classroomName) : nil

        var entry = TimetableEntry(
            id: "\(no)-\(from)-\(idSuffix)", lessonNo: no, start: from, end: to,
            subject: named(l.subject, lookups.subjectName) ?? "—",
            teacher: person(l.teacher, lookups),
            classroom: room,
            originalClassroom: orgRoom,
            movedFrom: movedFrom,
            movedTo: movedTo,
            originalTeacher: originalTeacher,
            originalSubject: originalSubject,
            isCancelled: l.isCancelled,
            isSubstitution: l.isSubstitution,
            note: nil
        )
        entry.note = note(for: entry, on: date)
        return entry
    }

    /// The one-line summary shown on the lesson's badge.
    static func note(for e: TimetableEntry, on date: Date) -> String? {
        switch e.changeKind {
        case .movedAway:
            return "Przeniesiona na " + describe(e.movedTo!, from: date, accusative: true)
        case .cancelled:
            return "Lekcja odwołana"
        case .movedHere:
            return "Przeniesiona z " + describe(e.movedFrom!, from: date, accusative: false)
        case .substitution:
            switch (e.originalTeacher, e.originalSubject) {
            case let (t?, s?): return "Zastępstwo za \(t), zamiast: \(s)"
            case let (t?, nil): return "Zastępstwo za \(t)"
            case let (nil, s?): return "Zamiana przedmiotu, było: \(s)"
            case (nil, nil): return "Zastępstwo"
            }
        case .roomOnly:
            return "Zmiana sali"
        case .none:
            return nil
        }
    }

    /// "lekcję 6" / "lekcji 8" on the same day, otherwise "21 paź, lekcja 3".
    static func describe(_ slot: LessonSlot, from date: Date, accusative: Bool) -> String {
        if LibrusDate.isSameDay(slot.date, date) {
            if let n = slot.lessonNo { return accusative ? "lekcję \(n)" : "lekcji \(n)" }
            if let s = slot.start { return s }
            return accusative ? "inną lekcję" : "innej lekcji"
        }
        var text = slot.date.dayMonthShort
        if let n = slot.lessonNo { text += ", lekcja \(n)" }
        else if let s = slot.start { text += ", \(s)" }
        return text
    }

    /// Compares by id when both are real ids, otherwise by resolved name.
    private static func differs(_ a: Int?, _ b: Int?, _ nameA: String?, _ nameB: String?) -> Bool {
        if let a, let b, a > 0, b > 0 { return a != b }
        guard let nameA, let nameB else { return false }
        return nameA != nameB
    }

    private static func named(_ ref: NamedRef?, _ table: [Int: String]) -> String? {
        guard let ref else { return nil }
        if let n = ref.name, !n.isEmpty { return n }
        if let n = table[ref.id], !n.isEmpty { return n }
        return nil
    }

    private static func person(_ ref: PersonRef?, _ lookups: Lookups) -> String? {
        guard let ref else { return nil }
        if let n = ref.displayName { return n }
        if let n = lookups.teacherName[ref.id], !n.isEmpty { return n }
        return nil
    }
}
