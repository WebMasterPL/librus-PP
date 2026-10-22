import XCTest
@testable import MojLibrus

final class SubjectAttendanceTests: XCTestCase {
    func testPercentCountsExcusedAndUnexcusedButNotLates() {
        let items: [AttendanceItem] = [
            make(.present, "Matematyka"), make(.present, "Matematyka"),
            make(.absent, "Matematyka"), make(.absentExcused, "Matematyka"),
            make(.belated, "Matematyka"),
            make(.present, "Fizyka"), make(.present, "Fizyka"),
            make(.absent, nil),
        ]
        let rows = SubjectAttendance.group(items)
        XCTAssertEqual(rows.map(\.subject), ["Matematyka", "Fizyka"])

        let math = rows[0]
        XCTAssertEqual(math.total, 5)
        XCTAssertEqual(math.absences, 2)
        XCTAssertEqual(math.belated, 1)
        XCTAssertEqual(math.absencePercent, 40, accuracy: 0.001)
        XCTAssertEqual(rows[1].absencePercent, 0)
    }

    /// Newest days first, lessons in order, only non-presences listed.
    func testRecentDays() throws {
        let mon = try XCTUnwrap(LibrusDate.fromYMD("2026-10-19"))
        let tue = try XCTUnwrap(LibrusDate.fromYMD("2026-10-20"))
        let wed = try XCTUnwrap(LibrusDate.fromYMD("2026-10-21"))
        let items: [AttendanceItem] = [
            make(.present, "Fizyka", date: wed, lessonNo: 2),
            make(.absent, "Matematyka", date: wed, lessonNo: 1),
            make(.present, "Fizyka", date: tue, lessonNo: 1),
            make(.belated, "Historia", date: tue, lessonNo: 3),
            make(.present, "Fizyka", date: mon, lessonNo: 1),
        ]
        let days = AttendanceDay.recent(items, limit: 2)
        XCTAssertEqual(days.map(\.date), [wed, tue])
        XCTAssertEqual(days[0].items.map(\.lessonNo), [1, 2])
        XCTAssertEqual(days[0].notable.map(\.subjectName), ["Matematyka"])
        XCTAssertEqual(days[1].notable.map(\.kind), [.belated])
    }

    /// Dashboard card: newest non-presences, the later lesson first on a day.
    func testRecentAbsences() throws {
        let tue = try XCTUnwrap(LibrusDate.fromYMD("2026-10-20"))
        let wed = try XCTUnwrap(LibrusDate.fromYMD("2026-10-21"))
        let items: [AttendanceItem] = [
            make(.absent, "Fizyka", date: tue, lessonNo: 2),
            make(.present, "Matematyka", date: wed, lessonNo: 5),
            make(.absentExcused, "Historia", date: wed, lessonNo: 1),
            make(.belated, "Biologia", date: wed, lessonNo: 3),
            make(.absent, "Chemia", date: tue, lessonNo: 1),
        ]
        let recent = AttendanceItem.recentAbsences(items, limit: 3)
        XCTAssertEqual(recent.map(\.subjectName), ["Biologia", "Historia", "Fizyka"])
    }

    private func make(_ kind: AttendanceKind, _ subject: String?,
                      date: Date = Date(), lessonNo: Int = 1) -> AttendanceItem {
        AttendanceItem(id: Int.random(in: 1...9_999_999), kind: kind, typeName: kind.label,
                       typeShort: "", colorHex: nil, date: date, lessonNo: lessonNo,
                       subjectName: subject, semester: 1)
    }
}
