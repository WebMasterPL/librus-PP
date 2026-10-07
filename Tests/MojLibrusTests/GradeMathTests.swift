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

    func testFormatPointTrimsWholeNumbers() {
        XCTAssertEqual(GradeMath.formatPoint(9), "9")
        XCTAssertEqual(GradeMath.formatPoint(9.5), "9.5")
        XCTAssertEqual(GradeMath.formatPoint(nil), "—")
    }

    /// A point grade must never feed the 1-6 average: it is stored with
    /// `weight` 0, so `weightedAverage` skips it whatever its own category weight.
    func testPointGradeNeverFeedsOneToSixAverage() {
        let point = makePointGrade(value: 9, max: 10, weight: 4)
        XCTAssertTrue(point.countsToAverage)
        XCTAssertEqual(GradeMath.weightedAverage([makeGrade(value: 5, weight: 1), point]), 5)
    }

    /// `colorValue` rescales a point grade onto the same 1-6 gradient the rest
    /// of the UI colours by, instead of treating "9" as an off-the-charts "6".
    func testPointGradeColorValueRescaledTo1Through6() {
        XCTAssertEqual(makePointGrade(value: 9, max: 10, weight: 4).colorValue, 5.5)
        XCTAssertEqual(makePointGrade(value: 10, max: 10, weight: 4).colorValue, 6)
    }

    /// 0 points usually means "not handed in yet": grey (nil), not red.
    func testZeroPointGradeIsGrey() {
        XCTAssertNil(makePointGrade(value: 0, max: 10, weight: 1).colorValue)
    }

    /// Weighted pooling: Σ(points·w) / Σ(max·w). 0/10 still counts as 0.
    func testPointPercentWeighted() {
        let grades = [
            makePointGrade(value: 9, max: 10, weight: 1),
            makePointGrade(value: 15, max: 20, weight: 2),
            makePointGrade(value: 0, max: 10, weight: 1),
        ]
        // (9 + 30 + 0) / (10 + 40 + 10) = 65%
        XCTAssertEqual(try XCTUnwrap(GradeMath.pointPercent(grades)), 65, accuracy: 0.001)
    }

    func testPointPercentSkipsNonCountingCategory() {
        let grades = [
            makePointGrade(value: 10, max: 10, weight: 1),
            makePointGrade(value: 0, max: 10, weight: 0),
        ]
        XCTAssertEqual(try XCTUnwrap(GradeMath.pointPercent(grades)), 100, accuracy: 0.001)
        XCTAssertNil(GradeMath.pointPercent([makeGrade(value: 5, weight: 1)]))
    }

    private func makePointGrade(value: Double?, max: Double?, weight: Double) -> GradeItem {
        GradeItem(id: Int.random(in: 1...9_999_999), raw: "9/10",
                  value: value, weight: 0, semester: 1, kind: .point,
                  categoryName: "Sprawdzian", teacherName: "Jan Kowalski",
                  subjectId: 1, subjectName: "WF", date: Date(), comment: nil,
                  pointMax: max, pointWeight: weight)
    }

    private func makeGrade(value: Double?, weight: Double) -> GradeItem {
        GradeItem(id: Int.random(in: 1...9_999_999), raw: value.map { "\(Int($0))" } ?? "np",
                  value: value, weight: weight, semester: 1, kind: .normal,
                  categoryName: "Kartkówka", teacherName: "Jan Kowalski",
                  subjectId: 1, subjectName: "Matematyka", date: Date(), comment: nil)
    }
}
