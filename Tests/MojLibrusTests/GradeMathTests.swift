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

    /// `colorValue` turns a point grade into the grade its percentage earns,
    /// instead of treating "9" as an off-the-charts "6".
    func testPointGradeColorValueFollowsPercentScale() {
        XCTAssertEqual(makePointGrade(value: 9, max: 10, weight: 4).colorValue, 4.5)   // 90% db+
        XCTAssertEqual(makePointGrade(value: 10, max: 10, weight: 4).colorValue, 5)    // bdb
        XCTAssertEqual(makePointGrade(value: 7, max: 20, weight: 1).colorValue, 2)     // 35% dop
        XCTAssertEqual(makePointGrade(value: 3, max: 10, weight: 1).colorValue, 1)     // ndst
    }

    func testPercentScaleThresholds() {
        let cases: [(Double, Double)] = [
            (100, 5), (91, 5), (90, 4.5), (86, 4.5), (85, 4), (75, 4), (74, 3.5), (70, 3.5),
            (69, 3), (55, 3), (54, 2.5), (50, 2.5), (49, 2), (35, 2), (34, 1), (0, 1),
        ]
        for (percent, grade) in cases {
            XCTAssertEqual(GradeMath.gradeValue(forPercent: percent), grade, "\(percent)%")
        }
        // Rounded like the label: 90.6% shows "91%" and colours as bdb.
        XCTAssertEqual(GradeMath.gradeValue(forPercent: 90.6), 5)
        XCTAssertEqual(GradeMath.gradeValue(forPercent: 90.4), 4.5)
        XCTAssertEqual(GradeMath.formatPercent(90.6), "91%")
    }

    func testPercentGradeLabels() {
        let cases: [(Double, String)] = [
            (100, "bdb"), (91, "bdb"), (90, "db+"), (86, "db+"), (85, "db"), (75, "db"),
            (74, "dst+"), (70, "dst+"), (69, "dst"), (55, "dst"), (54, "dop+"), (50, "dop+"),
            (49, "dop"), (35, "dop"), (34, "ndst"), (0, "ndst"),
        ]
        for (percent, label) in cases {
            XCTAssertEqual(GradeMath.gradeLabel(forPercent: percent), label, "\(percent)%")
        }
        XCTAssertEqual(GradeMath.formatPercentWithGrade(87.2), "87% · db+")
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
