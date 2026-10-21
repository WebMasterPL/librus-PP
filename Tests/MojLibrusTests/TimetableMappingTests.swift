import XCTest
@testable import MojLibrus

/// Change rules from `RawLesson`'s doc, on Librus-shaped JSON (names made up).
final class TimetableMappingTests: XCTestCase {
    private let lookups = TimetableMapping.Lookups(
        subjectName: [3: "Matematyka", 7: "Język niemiecki", 9: "Fizyka"],
        teacherName: [11: "Anna Nowak", 12: "Piotr Zieliński", 13: "Ewa Wiśniewska"],
        classroomName: [5: "12", 6: "204"]
    )

    private func day(_ json: String, _ date: String = "2026-10-19") throws -> [TimetableEntry] {
        let full = #"{ "Timetable": { "\#(date)": \#(json) } }"#
        let resp = try JSONDecoder().decode(RawTimetableResponse.self, from: Data(full.utf8))
        let slots = try XCTUnwrap(resp.days[date])
        return TimetableMapping.entries(for: slots, date: try XCTUnwrap(LibrusDate.fromYMD(date)),
                                        lookups: lookups)
    }

    /// A cancelled lesson plus another one moved into the same slot used to
    /// share an id, so the list drew the first one twice and hid the second.
    func testCancelledAndMovedHereShareASlotButNotAnId() throws {
        let entries = try day("""
        [ [], [], [], [], [], [], [
          { "LessonNo": 6, "HourFrom": "12:20", "HourTo": "13:05",
            "Subject": { "Id": 3, "Name": "Matematyka" },
            "Teacher": { "Id": 11, "FirstName": "Anna", "LastName": "Nowak" },
            "IsCanceled": true, "IsSubstitutionClass": false },
          { "LessonNo": 6, "HourFrom": "12:20", "HourTo": "13:05",
            "Subject": { "Id": 7, "Name": "Język niemiecki" },
            "Teacher": { "Id": 13, "FirstName": "Ewa", "LastName": "Wiśniewska" },
            "IsCanceled": false, "IsSubstitutionClass": true,
            "OrgDate": "2026-10-19", "OrgLessonNo": 8, "OrgHourFrom": "14:15",
            "OrgSubject": { "Id": 7 }, "OrgTeacher": { "Id": 13 } }
        ] ]
        """)
        XCTAssertEqual(entries.count, 2)
        XCTAssertNotEqual(entries[0].id, entries[1].id)

        // What actually happens in the slot comes first.
        XCTAssertEqual(entries[0].subject, "Język niemiecki")
        XCTAssertEqual(entries[0].changeKind, .movedHere)
        XCTAssertEqual(entries[0].note, "Przeniesiona z lekcji 8")
        XCTAssertNil(entries[0].originalTeacher)

        XCTAssertEqual(entries[1].subject, "Matematyka")
        XCTAssertEqual(entries[1].changeKind, .cancelled)
        XCTAssertEqual(entries[1].note, "Lekcja odwołana")
    }

    /// Substitution + cancelled = moved away, not a cancellation.
    func testMovedAwayIsNotACancellation() throws {
        let entries = try day("""
        [ [ { "LessonNo": 8, "HourFrom": "14:15", "HourTo": "15:00",
              "Subject": { "Id": 7, "Name": "Język niemiecki" },
              "Teacher": { "Id": 13, "FirstName": "Ewa", "LastName": "Wiśniewska" },
              "IsCanceled": true, "IsSubstitutionClass": true,
              "NewDate": "2026-10-19", "NewLessonNo": 6, "NewHourFrom": "12:20" } ] ]
        """)
        let e = try XCTUnwrap(entries.first)
        XCTAssertEqual(e.changeKind, .movedAway)
        XCTAssertTrue(e.isGone)
        XCTAssertEqual(e.note, "Przeniesiona na lekcję 6")
        XCTAssertEqual(e.movedTo?.lessonNo, 6)
    }

    func testMovedToAnotherDay() throws {
        let entries = try day("""
        [ [ { "LessonNo": 3, "HourFrom": "09:40", "HourTo": "10:25",
              "Subject": { "Id": 9, "Name": "Fizyka" },
              "IsCanceled": false, "IsSubstitutionClass": true,
              "OrgDate": "2026-10-16", "OrgLessonNo": 5 } ] ]
        """, "2026-10-21")
        let e = try XCTUnwrap(entries.first)
        XCTAssertEqual(e.changeKind, .movedHere)
        XCTAssertEqual(e.note, "Przeniesiona z 16 paź, lekcja 5")
    }

    /// Org refs that carry only an id are resolved through the lookup tables.
    func testSubstitutionNamesTheCoveredTeacherFromIdOnlyRef() throws {
        let entries = try day("""
        [ [ { "LessonNo": 5, "HourFrom": "11:30", "HourTo": "12:15",
              "Subject": { "Id": 3, "Name": "Matematyka" },
              "Teacher": { "Id": 12, "FirstName": "Piotr", "LastName": "Zieliński" },
              "IsCanceled": false, "IsSubstitutionClass": true,
              "OrgDate": "2026-10-19", "OrgLessonNo": 5,
              "OrgSubject": { "Id": 3 }, "OrgTeacher": { "Id": 11 } } ] ]
        """)
        let e = try XCTUnwrap(entries.first)
        XCTAssertEqual(e.changeKind, .substitution)
        XCTAssertEqual(e.originalTeacher, "Anna Nowak")
        XCTAssertNil(e.originalSubject)
        XCTAssertEqual(e.note, "Zastępstwo za Anna Nowak")
    }

    func testSubjectSwapWithSameTeacher() throws {
        let entries = try day("""
        [ [ { "LessonNo": 2, "HourFrom": "08:50", "HourTo": "09:35",
              "Subject": { "Id": 9, "Name": "Fizyka" },
              "Teacher": { "Id": 11, "FirstName": "Anna", "LastName": "Nowak" },
              "IsCanceled": false, "IsSubstitutionClass": true,
              "OrgDate": "2026-10-19", "OrgLessonNo": 2,
              "OrgSubject": { "Id": 3 }, "OrgTeacher": { "Id": 11 } } ] ]
        """)
        let e = try XCTUnwrap(entries.first)
        XCTAssertNil(e.originalTeacher)
        XCTAssertEqual(e.originalSubject, "Matematyka")
        XCTAssertEqual(e.note, "Zamiana przedmiotu, było: Matematyka")
    }

    func testRoomOnlyChange() throws {
        let entries = try day("""
        [ [ { "LessonNo": 1, "HourFrom": "08:00", "HourTo": "08:45",
              "Subject": { "Id": 3, "Name": "Matematyka" },
              "Teacher": { "Id": 11, "FirstName": "Anna", "LastName": "Nowak" },
              "Classroom": { "Id": 6 },
              "IsCanceled": false, "IsSubstitutionClass": true,
              "OrgDate": "2026-10-19", "OrgLessonNo": 1,
              "OrgSubject": { "Id": 3 }, "OrgTeacher": { "Id": 11 }, "OrgClassroom": { "Id": 5 } } ] ]
        """)
        let e = try XCTUnwrap(entries.first)
        XCTAssertEqual(e.changeKind, .roomOnly)
        XCTAssertEqual(e.classroom, "204")
        XCTAssertEqual(e.originalClassroom, "12")
        XCTAssertEqual(e.note, "Zmiana sali")
    }

    /// One row per lesson number: the lesson taking place leads, the cancelled
    /// one it replaced hangs under it; a slot with only a moved-away lesson
    /// still gets its own row.
    func testLessonGroupsOneRowPerNumber() throws {
        let entries = try day("""
        [ [
          { "LessonNo": 4, "HourFrom": "10:35", "HourTo": "11:20",
            "Subject": { "Id": 3, "Name": "Matematyka" },
            "IsCanceled": true, "IsSubstitutionClass": false },
          { "LessonNo": 4, "HourFrom": "10:35", "HourTo": "11:20",
            "Subject": { "Id": 9, "Name": "Fizyka" },
            "IsCanceled": false, "IsSubstitutionClass": true,
            "OrgDate": "2026-10-19", "OrgLessonNo": 7 }
        ], [
          { "LessonNo": 7, "HourFrom": "13:25", "HourTo": "14:10",
            "Subject": { "Id": 9, "Name": "Fizyka" },
            "IsCanceled": true, "IsSubstitutionClass": true,
            "NewDate": "2026-10-19", "NewLessonNo": 4 }
        ] ]
        """)
        let groups = TimetableDay(date: Date(), entries: entries).lessonGroups
        XCTAssertEqual(groups.map(\.lessonNo), [4, 7])
        XCTAssertEqual(groups[0].primary.map(\.subject), ["Fizyka"])
        XCTAssertEqual(groups[0].replaced.map(\.subject), ["Matematyka"])
        XCTAssertEqual(groups[1].lead.changeKind, .movedAway)
        XCTAssertTrue(groups[1].replaced.isEmpty)
    }

    /// The same lesson listed twice in one slot (e.g. once per group) shows once.
    func testExactDuplicatesAreMerged() throws {
        let lesson = """
        { "LessonNo": 4, "HourFrom": "10:35", "HourTo": "11:20",
          "Subject": { "Id": 3, "Name": "Matematyka" },
          "Teacher": { "Id": 11, "FirstName": "Anna", "LastName": "Nowak" },
          "IsCanceled": true, "IsSubstitutionClass": false }
        """
        let entries = try day("[ [ \(lesson), \(lesson) ] ]")
        XCTAssertEqual(entries.count, 1)
    }
}
