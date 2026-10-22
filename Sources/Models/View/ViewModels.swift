import Foundation

// Joined, display-ready models produced by `DataRepository`.

// MARK: - Grades

enum GradeKind: String, Codable {
    case normal
    /// A school-configurable alternate scale (e.g. "9/10") — see `pointMax`.
    case point
    case semesterProposed, semesterFinal
    case yearProposed, yearFinal
}

struct GradeItem: Identifiable, Codable, Hashable {
    let id: Int
    let raw: String
    let value: Double?
    let weight: Double
    let semester: Int
    let kind: GradeKind
    let categoryName: String
    let teacherName: String
    let subjectId: Int
    let subjectName: String
    let date: Date?
    let comment: String?
    /// Top of the scale for a `.point` grade (e.g. 10 for "9/10"); nil otherwise.
    var pointMax: Double? = nil
    /// The point category's averaging weight (0 = not counted); nil otherwise.
    var pointWeight: Double? = nil

    var countsToAverage: Bool {
        switch kind {
        case .normal: return value != nil && weight > 0
        case .point: return value != nil && (pointMax ?? 0) > 0 && (pointWeight ?? 0) > 0
        default: return false
        }
    }

    /// `value` on the 1-6 scale `gradeColor` expects — a `.point` grade becomes
    /// the grade its percentage earns (`GradeMath.gradeValue(forPercent:)`), so
    /// "9/10" colours as db+, not as an off-the-charts "9". 0 points usually
    /// means "not handed in yet", so it goes grey (nil) rather than alarm-red;
    /// it still counts as 0 in averages.
    var colorValue: Double? {
        guard kind == .point, let value, let pointMax, pointMax > 0 else { return value }
        guard value > 0 else { return nil }
        return GradeMath.gradeValue(forPercent: value * 100 / pointMax)
    }
}

struct SubjectGrades: Identifiable, Codable, Hashable {
    var id: Int { subjectId }
    let subjectId: Int
    let subjectName: String
    var grades: [GradeItem]

    func filtered(_ filter: SemesterFilter, current: Int) -> [GradeItem] {
        grades.filter { filter.matches($0.semester, current: current) }
    }

    func normalGrades(_ filter: SemesterFilter, current: Int) -> [GradeItem] {
        filtered(filter, current: current).filter { $0.kind == .normal }
    }

    func average(_ filter: SemesterFilter, current: Int) -> Double? {
        GradeMath.weightedAverage(normalGrades(filter, current: current))
    }

    /// Weighted percentage over point grades: Σ(points·w) / Σ(max·w).
    func pointPercent(_ filter: SemesterFilter, current: Int) -> Double? {
        GradeMath.pointPercent(filtered(filter, current: current))
    }

    func proposedFinal(_ filter: SemesterFilter, current: Int) -> GradeItem? {
        filtered(filter, current: current).first { $0.kind == .yearProposed || $0.kind == .semesterProposed }
    }

    func finalGrade(_ filter: SemesterFilter, current: Int) -> GradeItem? {
        filtered(filter, current: current).first { $0.kind == .yearFinal || $0.kind == .semesterFinal }
    }
}

// MARK: - Timetable

struct TimetableEntry: Identifiable, Codable, Hashable {
    let id: String
    let lessonNo: Int
    let start: String
    let end: String
    let subject: String
    let teacher: String?
    let classroom: String?
    /// Set only when the room differs from the originally planned one.
    let originalClassroom: String?
    /// This lesson was moved here from another slot (same day or not).
    var movedFrom: LessonSlot? = nil
    /// This lesson was moved away from this slot — it doesn't take place here.
    var movedTo: LessonSlot? = nil
    /// The regularly-assigned teacher being covered for — set only when a
    /// substitution genuinely swapped teachers. `teacher` above is whoever is
    /// actually taking the lesson.
    let originalTeacher: String?
    /// The subject originally planned in this slot, when a change swapped it.
    var originalSubject: String? = nil
    let isCancelled: Bool
    let isSubstitution: Bool
    /// Ready-to-show one-line summary of the change (badge text).
    var note: String?

    var roomChanged: Bool {
        guard let originalClassroom, let classroom else { return false }
        return !originalClassroom.isEmpty && originalClassroom != classroom
    }

    enum ChangeKind { case none, cancelled, movedAway, movedHere, substitution, roomOnly }

    var changeKind: ChangeKind {
        if movedTo != nil { return .movedAway }
        if isCancelled { return .cancelled }
        if movedFrom != nil { return .movedHere }
        if isSubstitution {
            return originalTeacher == nil && originalSubject == nil && roomChanged ? .roomOnly : .substitution
        }
        return .none
    }

    /// Not happening in this slot (cancelled or moved elsewhere).
    var isGone: Bool { isCancelled || movedTo != nil }

    var startMinutes: Int? { LibrusDate.minutesOfDay(start) }
    var endMinutes: Int? { LibrusDate.minutesOfDay(end) }

    func isOngoing(nowMinutes: Int = LibrusDate.nowMinutesOfDay) -> Bool {
        guard let s = startMinutes, let e = endMinutes else { return false }
        return nowMinutes >= s && nowMinutes < e
    }

    func isUpcoming(nowMinutes: Int = LibrusDate.nowMinutesOfDay) -> Bool {
        guard let s = startMinutes else { return false }
        return s > nowMinutes
    }
}

/// One place in the timetable: a day plus, when Librus gives it, the lesson
/// number and start time.
struct LessonSlot: Codable, Hashable {
    let date: Date
    let lessonNo: Int?
    let start: String?
}

struct TimetableDay: Identifiable, Codable, Hashable {
    var id: Date { date }
    let date: Date
    let entries: [TimetableEntry]

    var hasLessons: Bool { !entries.isEmpty }

    /// One row per lesson number: what takes place in full, and under it
    /// whatever it replaced (cancelled or moved away) — two rows with the same
    /// number read as a duplicate.
    var lessonGroups: [LessonGroup] {
        var out: [LessonGroup] = []
        var i = entries.startIndex
        while i < entries.endIndex {
            var j = i
            while j < entries.endIndex && entries[j].lessonNo == entries[i].lessonNo { j += 1 }
            let slot = entries[i..<j]
            var primary = slot.filter { !$0.isGone }
            var replaced = slot.filter { $0.isGone }
            if primary.isEmpty { primary = [replaced.removeFirst()] }
            out.append(LessonGroup(lessonNo: entries[i].lessonNo, primary: primary, replaced: replaced))
            i = j
        }
        return out
    }
}

struct LessonGroup: Identifiable, Hashable {
    var id: String { primary[0].id }
    let lessonNo: Int
    /// Never empty; shown in full.
    let primary: [TimetableEntry]
    /// Cancelled or moved-away lessons of the same slot, shown compactly.
    let replaced: [TimetableEntry]

    var lead: TimetableEntry { primary[0] }
}

// MARK: - Attendance

enum AttendanceKind: String, Codable, CaseIterable {
    case present, presentCustom, absent, absentExcused, belated, released

    var label: String {
        switch self {
        case .present: return "Obecność"
        case .presentCustom: return "Obecność (inne)"
        case .absent: return "Nieobecność"
        case .absentExcused: return "Nieob. usprawiedliwiona"
        case .belated: return "Spóźnienie"
        case .released: return "Zwolnienie"
        }
    }

    var countsAsAbsence: Bool { self == .absent }
}

struct AttendanceItem: Identifiable, Codable, Hashable {
    let id: Int
    let kind: AttendanceKind
    let typeName: String
    let typeShort: String
    let colorHex: String?
    let date: Date?
    let lessonNo: Int?
    let subjectName: String?
    let semester: Int?
}

struct AttendanceSummary: Codable, Hashable {
    var counts: [AttendanceKind: Int] = [:]

    var total: Int { counts.values.reduce(0, +) }
    var present: Int { (counts[.present] ?? 0) + (counts[.presentCustom] ?? 0) }
    var absent: Int { counts[.absent] ?? 0 }
    var absentExcused: Int { counts[.absentExcused] ?? 0 }
    var belated: Int { counts[.belated] ?? 0 }
    var released: Int { counts[.released] ?? 0 }

    /// Common PL-school rule: every 3 lates become one absence. The individual
    /// entries still show as lates — only these totals and the percentage change.
    var latesCountedAsAbsence: Int { belated / 3 }
    /// Recorded absences plus the ones converted from lates.
    var effectiveAbsent: Int { absent + latesCountedAsAbsence }

    /// (present + lates that didn't tip into an absence) / everything considered.
    var attendancePercent: Double? {
        let considered = present + absent + absentExcused + belated + released
        guard considered > 0 else { return nil }
        let latesStillPresent = belated - latesCountedAsAbsence
        return Double(present + latesStillPresent) / Double(considered) * 100
    }
}

/// One subject's share of absences. Librus records an entry for every lesson
/// (presence included), so `total` is the number of lessons with attendance.
struct SubjectAttendance: Identifiable, Hashable {
    var id: String { subject }
    let subject: String
    let total: Int
    let absent: Int
    let excused: Int
    let belated: Int

    var absences: Int { absent + excused }
    var absencePercent: Double { total > 0 ? Double(absences) / Double(total) * 100 : 0 }

    /// Highest absence share first; subjects with no absences come last, by name.
    static func group(_ items: [AttendanceItem]) -> [SubjectAttendance] {
        Dictionary(grouping: items.filter { $0.subjectName != nil }) { $0.subjectName ?? "" }
            .map { name, entries in
                SubjectAttendance(
                    subject: name, total: entries.count,
                    absent: entries.filter { $0.kind == .absent }.count,
                    excused: entries.filter { $0.kind == .absentExcused }.count,
                    belated: entries.filter { $0.kind == .belated }.count
                )
            }
            .sorted {
                $0.absencePercent != $1.absencePercent
                    ? $0.absencePercent > $1.absencePercent
                    : $0.subject.localizedCaseInsensitiveCompare($1.subject) == .orderedAscending
            }
    }
}

/// One school day's attendance, lessons in order — the "Ostatnie dni" panel.
struct AttendanceDay: Identifiable, Hashable {
    var id: Date { date }
    let date: Date
    let items: [AttendanceItem]

    /// Everything but a plain presence, listed by subject under the day.
    var notable: [AttendanceItem] { items.filter { $0.kind != .present } }

    /// The newest `limit` days that have entries, newest first.
    static func recent(_ items: [AttendanceItem], limit: Int) -> [AttendanceDay] {
        let cal = LibrusDate.calendar
        let byDay = Dictionary(grouping: items.filter { $0.date != nil }) { cal.startOfDay(for: $0.date!) }
        return byDay.keys.sorted(by: >).prefix(limit).map { day in
            AttendanceDay(date: day, items: (byDay[day] ?? []).sorted { ($0.lessonNo ?? 0) < ($1.lessonNo ?? 0) })
        }
    }
}

// MARK: - Announcements / homework / lucky number

struct AnnouncementItem: Identifiable, Codable, Hashable {
    let id: String
    let subject: String
    let content: String
    let author: String?
    let date: Date?
    let wasReadOnServer: Bool
}

struct CalendarEvent: Identifiable, Codable, Hashable {
    let id: Int
    let date: Date?
    let content: String
    let category: String?
    let subject: String?
    let teacher: String?
    let lessonNo: Int?
    let time: String?

    var isPast: Bool {
        guard let date else { return false }
        return date < LibrusDate.today
    }
}

struct BellPeriod: Identifiable, Codable, Hashable {
    var id: Int { number }
    let number: Int
    let start: String
    let end: String
}

/// A teacher's absence, school-wide (scraped off the Terminarz calendar — see
/// `MessagesClient.teacherAbsences`) — independent of the student's own
/// timetable, so it also covers teachers who don't teach them.
struct TeacherAbsence: Identifiable, Codable, Hashable {
    let id: Int
    let teacherName: String
    let dateFrom: Date
    let dateTo: Date
    /// Both nil = absent the whole day.
    let timeFrom: String?
    let timeTo: String?

    var isFullDay: Bool { timeFrom == nil && timeTo == nil }

    func includes(_ date: Date) -> Bool {
        let day = LibrusDate.calendar.startOfDay(for: date)
        return day >= LibrusDate.calendar.startOfDay(for: dateFrom)
            && day <= LibrusDate.calendar.startOfDay(for: dateTo)
    }
}

// MARK: - Behaviour notes (uwagi)

struct NoteItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case positive, negative, neutral }
    let id: Int
    let text: String
    let category: String?
    let teacher: String?
    let date: Date?
    let kind: Kind
}

// MARK: - School year / semester

struct SchoolYearInfo: Codable, Hashable {
    var className: String? = nil
    var tutor: String? = nil
    var yearStart: Date? = nil
    var secondSemesterStart: Date? = nil
    var yearEnd: Date? = nil

    /// Semester that contains `date`, using the real Librus boundary when known.
    func semester(on date: Date = Date()) -> Int {
        guard let boundary = secondSemesterStart else {
            // Fallback: Polish school year — Feb..Aug ≈ semester 2.
            let month = LibrusDate.calendar.component(.month, from: date)
            return (2...8).contains(month) ? 2 : 1
        }
        return date < boundary ? 1 : 2
    }
}

enum SemesterFilter: String, CaseIterable, Identifiable {
    case current, first, second, all
    var id: String { rawValue }
    var label: String {
        switch self {
        case .current: return "Bieżący"
        case .first: return "Sem. 1"
        case .second: return "Sem. 2"
        case .all: return "Całość"
        }
    }
    func matches(_ semester: Int, current: Int) -> Bool {
        switch self {
        case .current: return semester == current
        case .first: return semester == 1
        case .second: return semester == 2
        case .all: return true
        }
    }
}

// MARK: - Messages

struct MessageItem: Identifiable, Codable, Hashable {
    let id: Int
    let subject: String
    let correspondent: String
    let sentDate: Date?
    let readDateServer: Date?
    let hasAttachments: Bool
    var body: String?

    var isUnread: Bool { readDateServer == nil }
}
