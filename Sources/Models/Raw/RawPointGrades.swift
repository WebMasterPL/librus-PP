import Foundation

/// `PointGrades` — an alternate, school-configurable scale (e.g. "9/10") used
/// instead of, or alongside, the standard 1-6 `Grades` scale. Field names
/// confirmed against szkolny-eu/szkolny-android's `LibrusApiPointGrades.kt`.
struct RawPointGradesResponse: Decodable {
    let grades: [RawPointGrade]
    enum CodingKeys: String, CodingKey { case grades = "Grades" }
}

struct RawPointGrade: Decodable {
    let id: Int
    /// Display text as Librus renders it (often just the number, e.g. "9").
    let grade: String
    let gradeValue: Double?
    let addDate: String?
    let semester: Int
    let category: Ref?
    let addedBy: Ref?
    let subject: Ref?

    enum CodingKeys: String, CodingKey {
        case id = "Id", grade = "Grade", gradeValue = "GradeValue", addDate = "AddDate"
        case semester = "Semester", category = "Category", addedBy = "AddedBy", subject = "Subject"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        grade = (try? c.decode(String.self, forKey: .grade)) ?? ""
        gradeValue = try? c.decode(Double.self, forKey: .gradeValue)
        addDate = try? c.decode(String.self, forKey: .addDate)
        semester = c.decodeFlexInt(.semester) ?? 1
        category = try? c.decode(Ref.self, forKey: .category)
        addedBy = try? c.decode(Ref.self, forKey: .addedBy)
        subject = try? c.decode(Ref.self, forKey: .subject)
    }
}

struct RawPointGradeCategoriesResponse: Decodable {
    let categories: [RawPointGradeCategory]
    enum CodingKeys: String, CodingKey { case categories = "Categories" }
}

/// Unlike `Grades/Categories`, each point category also carries the scale's
/// range (`ValueFrom`…`ValueTo`) — that's where the "/10" in "9/10" comes from.
struct RawPointGradeCategory: Decodable {
    let id: Int
    let name: String
    let countToAverage: Bool
    let weight: Double
    let valueFrom: Double
    let valueTo: Double

    enum CodingKeys: String, CodingKey {
        case id = "Id", name = "Name"
        case countToAverage = "CountToTheAverage", weight = "Weight"
        case valueFrom = "ValueFrom", valueTo = "ValueTo"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        countToAverage = (try? c.decode(Bool.self, forKey: .countToAverage)) ?? false
        weight = (try? c.decode(Double.self, forKey: .weight)) ?? 0
        valueFrom = (try? c.decode(Double.self, forKey: .valueFrom)) ?? 0
        valueTo = (try? c.decode(Double.self, forKey: .valueTo)) ?? 0
    }

    var effectiveWeight: Double { countToAverage ? weight : 0 }
}
