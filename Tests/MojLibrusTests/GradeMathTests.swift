import XCTest
@testable import MojLibrus

final class GradeMathTests: XCTestCase {
    func testNumericValueParsing() {
        XCTAssertEqual(GradeMath.numericValue(of: "5"), 5)
        XCTAssertEqual(GradeMath.numericValue(of: "4+"), 4.5)
        XCTAssertEqual(GradeMath.numericValue(of: "3-"), 2.75)
        XCTAssertEqual(GradeMath.numericValue(of: "6"), 6)
        XCTAssertNil(GradeMath.numericValue(of: "np"))
        XCTAssertNil(GradeMath.numericValue(of: "bz"))
        XCTAssertNil(GradeMath.numericValue(of: "+"))
        XCTAssertNil(GradeMath.numericValue(of: "-"))
        XCTAssertNil(GradeMath.numericValue(of: ""))
        XCTAssertNil(GradeMath.numericValue(of: "7"))
    }

    func testWeightedAverage() {
        let grades = [
            makeGrade(value: 5, weight: 3),
            makeGrade(value: 3, weight: 1),
            makeGrade(value: 4, weight: 0), // ignored (no weight)
            makeGrade(value: nil, weight: 2), // ignored (no value)
        ]
        // (5*3 + 3*1) / (3+1) = 18/4 = 4.5
        XCTAssertEqual(GradeMath.weightedAverage(grades), 4.5)
    }

    func testWeightedAverageEmpty() {
        XCTAssertNil(GradeMath.weightedAverage([]))
        XCTAssertNil(GradeMath.weightedAverage([makeGrade(value: nil, weight: 1)]))
    }

    func testArithmeticAverage() {
        let grades = [makeGrade(value: 5, weight: 1), makeGrade(value: 4, weight: 1)]
        XCTAssertEqual(GradeMath.arithmeticAverage(grades), 4.5)
    }

    private func makeGrade(value: Double?, weight: Double) -> GradeItem {
        GradeItem(id: Int.random(in: 1...9_999_999), raw: value.map { "\(Int($0))" } ?? "np",
                  value: value, weight: weight, semester: 1, kind: .normal,
                  categoryName: "Kartkówka", teacherName: "Jan Kowalski",
                  subjectId: 1, subjectName: "Matematyka", date: Date(), comment: nil)
    }
}
