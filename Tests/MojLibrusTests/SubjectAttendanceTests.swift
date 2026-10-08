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

    private func make(_ kind: AttendanceKind, _ subject: String?) -> AttendanceItem {
        AttendanceItem(id: Int.random(in: 1...9_999_999), kind: kind, typeName: kind.label,
                       typeShort: "", colorHex: nil, date: Date(), lessonNo: 1,
                       subjectName: subject, semester: 1)
    }
}
