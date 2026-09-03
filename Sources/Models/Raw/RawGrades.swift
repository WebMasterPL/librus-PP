import Foundation

struct RawGradesResponse: Decodable {
    let grades: [RawGrade]
    enum CodingKeys: String, CodingKey { case grades = "Grades" }
}

struct RawGrade: Decodable {
    let id: Int
    let grade: String
    let addDate: String?
    let semester: Int
    let category: Ref?
    let addedBy: Ref?
    let subject: Ref?
    let isConstituent: Bool
    let isSemester: Bool
    let isSemesterProposition: Bool
    let isFinal: Bool
    let isFinalProposition: Bool
    let commentIds: [Int]

    enum CodingKeys: String, CodingKey {
        case id = "Id", grade = "Grade", addDate = "AddDate", semester = "Semester"
        case category = "Category", addedBy = "AddedBy", subject = "Subject"
        case isConstituent = "IsConstituent", isSemester = "IsSemester"
        case isSemesterProposition = "IsSemesterProposition"
        case isFinal = "IsFinal", isFinalProposition = "IsFinalProposition"
        case comments = "Comments"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        grade = (try? c.decode(String.self, forKey: .grade)) ?? ""
        addDate = try? c.decode(String.self, forKey: .addDate)
        semester = c.decodeFlexInt(.semester) ?? 1
        category = try? c.decode(Ref.self, forKey: .category)
        addedBy = try? c.decode(Ref.self, forKey: .addedBy)
        subject = try? c.decode(Ref.self, forKey: .subject)
        isConstituent = (try? c.decode(Bool.self, forKey: .isConstituent)) ?? false
        isSemester = (try? c.decode(Bool.self, forKey: .isSemester)) ?? false
        isSemesterProposition = (try? c.decode(Bool.self, forKey: .isSemesterProposition)) ?? false
        isFinal = (try? c.decode(Bool.self, forKey: .isFinal)) ?? false
        isFinalProposition = (try? c.decode(Bool.self, forKey: .isFinalProposition)) ?? false
        commentIds = ((try? c.decode([Ref].self, forKey: .comments)) ?? []).map(\.id)
    }
}

struct RawGradeCommentsResponse: Decodable {
    let comments: [RawGradeComment]
    enum CodingKeys: String, CodingKey { case comments = "Comments" }
}

struct RawGradeComment: Decodable {
    let id: Int
    let text: String

    enum CodingKeys: String, CodingKey { case id = "Id", text = "Text" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
    }
}
