import XCTest
@testable import MojLibrus

final class SemesterTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testSemesterBoundaryFromClasses() {
        var info = SchoolYearInfo()
        info.secondSemesterStart = LibrusDate.fromYMD("2026-01-26")

        XCTAssertEqual(info.semester(on: LibrusDate.fromYMD("2025-11-15")!), 1)
        XCTAssertEqual(info.semester(on: LibrusDate.fromYMD("2026-01-25")!), 1)
        XCTAssertEqual(info.semester(on: LibrusDate.fromYMD("2026-01-26")!), 2)
        XCTAssertEqual(info.semester(on: LibrusDate.fromYMD("2026-05-01")!), 2)
    }

    func testSemesterFallbackWithoutBoundary() {
        let info = SchoolYearInfo()
        XCTAssertEqual(info.semester(on: LibrusDate.fromYMD("2026-10-01")!), 1)
        XCTAssertEqual(info.semester(on: LibrusDate.fromYMD("2026-04-01")!), 2)
    }

    func testSemesterFilterMatching() {
        XCTAssertTrue(SemesterFilter.current.matches(2, current: 2))
        XCTAssertFalse(SemesterFilter.current.matches(1, current: 2))
        XCTAssertTrue(SemesterFilter.first.matches(1, current: 2))
        XCTAssertTrue(SemesterFilter.all.matches(1, current: 2))
        XCTAssertTrue(SemesterFilter.all.matches(2, current: 1))
    }

    func testDecodeClasses() throws {
        let json = """
        { "Class": { "Id": 5, "Number": "3", "Symbol": "A",
          "ClassTutor": { "Id": 42 },
          "BeginSchoolYear": "2025-09-01", "EndFirstSemester": "2026-01-26",
          "EndSchoolYear": "2026-06-26" } }
        """
        let resp = try decoder.decode(RawClassesResponse.self, from: Data(json.utf8))
        let c = try XCTUnwrap(resp.studentClass)
        XCTAssertEqual(c.name, "3A")
        XCTAssertEqual(c.classTutor?.id, 42)
        XCTAssertEqual(c.endFirstSemester, "2026-01-26")
    }

    func testDecodeEvents() throws {
        let json = """
        { "HomeWorks": [
          { "Id": 900, "Date": "2026-09-15", "Content": "Sprawdzian – funkcje",
            "Category": { "Id": 2 }, "CreatedBy": { "Id": 9 }, "Subject": { "Id": 3 },
            "LessonNo": 4, "TimeFrom": "10:40:00", "AddDate": "2026-09-01 12:00:00" }
        ] }
        """
        let resp = try decoder.decode(RawEventsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(resp.events.count, 1)
        XCTAssertEqual(resp.events[0].id, 900)
        XCTAssertEqual(resp.events[0].category?.id, 2)
        XCTAssertEqual(resp.events[0].subject?.id, 3)
        XCTAssertEqual(resp.events[0].lessonNo, 4)
    }

    func testDecodeNotes() throws {
        let json = """
        { "Notes": [
          { "Id": 1, "Text": "Świetna praca", "Category": { "Id": 3 },
            "Teacher": { "Id": 9 }, "Date": "2026-03-01", "Positive": 1 },
          { "Id": 2, "Text": "Brak zadania", "Date": "2026-03-02", "Positive": 0 }
        ] }
        """
        let resp = try decoder.decode(RawNotesResponse.self, from: Data(json.utf8))
        XCTAssertEqual(resp.notes.count, 2)
        XCTAssertEqual(resp.notes[0].positive, 1)
        XCTAssertEqual(resp.notes[1].positive, 0)
        XCTAssertEqual(resp.notes[0].category?.id, 3)
    }

    func testSubjectGradesSemesterAverage() {
        let s = SubjectGrades(subjectId: 1, subjectName: "Matematyka", grades: [
            grade(id: 1, raw: "5", value: 5, weight: 1, semester: 1),
            grade(id: 2, raw: "3", value: 3, weight: 1, semester: 1),
            grade(id: 3, raw: "6", value: 6, weight: 1, semester: 2),
        ])
        XCTAssertEqual(s.average(.first, current: 2), 4)
        XCTAssertEqual(s.average(.second, current: 2), 6)
        XCTAssertEqual(s.average(.current, current: 2), 6)
        XCTAssertEqual(s.average(.all, current: 2).map { ($0 * 100).rounded() / 100 }, 4.67)
    }

    func testGradeMathCommaAndClamp() {
        XCTAssertEqual(GradeMath.numericValue(of: "1-"), 0.75)
        XCTAssertEqual(GradeMath.numericValue(of: "2,5"), 2.5)
        XCTAssertNil(GradeMath.numericValue(of: "8"))
        XCTAssertNil(GradeMath.numericValue(of: "nb"))
    }

    private func grade(id: Int, raw: String, value: Double?, weight: Double, semester: Int) -> GradeItem {
        GradeItem(id: id, raw: raw, value: value, weight: weight, semester: semester, kind: .normal,
                  categoryName: "", teacherName: "", subjectId: 1, subjectName: "Matematyka",
                  date: nil, comment: nil)
    }
}
