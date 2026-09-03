import Foundation

// MARK: - Classes (school-year dates, class name, tutor)

struct RawClassesResponse: Decodable {
    let studentClass: RawStudentClass?
    enum CodingKeys: String, CodingKey { case studentClass = "Class" }
}

struct RawStudentClass: Decodable {
    let id: Int
    let number: String?
    let symbol: String?
    let classTutor: Ref?
    let beginSchoolYear: String?
    let endFirstSemester: String?
    let endSchoolYear: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id", number = "Number", symbol = "Symbol", classTutor = "ClassTutor"
        case beginSchoolYear = "BeginSchoolYear"
        case endFirstSemester = "EndFirstSemester"
        case endSchoolYear = "EndSchoolYear"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        number = try? c.decode(String.self, forKey: .number)
        symbol = try? c.decode(String.self, forKey: .symbol)
        classTutor = try? c.decode(Ref.self, forKey: .classTutor)
        beginSchoolYear = try? c.decode(String.self, forKey: .beginSchoolYear)
        endFirstSemester = try? c.decode(String.self, forKey: .endFirstSemester)
        endSchoolYear = try? c.decode(String.self, forKey: .endSchoolYear)
    }

    var name: String {
        "\((number ?? ""))\((symbol ?? ""))".trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Behaviour notes (uwagi)

struct RawNotesResponse: Decodable {
    let notes: [RawNote]
    enum CodingKeys: String, CodingKey { case notes = "Notes" }
}

struct RawNote: Decodable {
    let id: Int
    let text: String
    let category: Ref?
    let teacher: Ref?
    let date: String?
    /// 0 = negatywna, 1 = pozytywna, 2 = neutralna
    let positive: Int

    enum CodingKeys: String, CodingKey {
        case id = "Id", text = "Text", category = "Category"
        case teacher = "Teacher", date = "Date", positive = "Positive"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        category = try? c.decode(Ref.self, forKey: .category)
        teacher = try? c.decode(Ref.self, forKey: .teacher)
        date = try? c.decode(String.self, forKey: .date)
        positive = c.decodeFlexInt(.positive) ?? 2
    }
}

struct RawNoteCategoriesResponse: Decodable {
    let categories: [RawNoteCategory]
    enum CodingKeys: String, CodingKey { case categories = "Categories" }
}

struct RawNoteCategory: Decodable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey { case id = "Id", name = "CategoryName" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
    }
}

// MARK: - School (bell schedule + name)

struct RawSchoolResponse: Decodable {
    let school: RawSchool?
    enum CodingKeys: String, CodingKey { case school = "School" }
}

struct RawSchool: Decodable {
    let name: String?
    let town: String?
    let lessonsRange: [RawLessonRange]

    enum CodingKeys: String, CodingKey {
        case name = "Name", town = "Town", lessonsRange = "LessonsRange"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decode(String.self, forKey: .name)
        town = try? c.decode(String.self, forKey: .town)
        lessonsRange = (try? c.decode([RawLessonRange].self, forKey: .lessonsRange)) ?? []
    }
}

struct RawLessonRange: Decodable {
    let from: String?
    let to: String?
    enum CodingKeys: String, CodingKey { case from = "From", to = "To" }
}

// MARK: - Calendar events (terminarz — HomeWorks endpoint, not homework)

struct RawEventsResponse: Decodable {
    let events: [RawEvent]
    enum CodingKeys: String, CodingKey { case events = "HomeWorks" }
}

struct RawEvent: Decodable {
    let id: Int
    let date: String?
    let content: String
    let category: Ref?
    let createdBy: Ref?
    let subject: Ref?
    let lessonNo: Int?
    let timeFrom: String?
    let addDate: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id", date = "Date", content = "Content", category = "Category"
        case createdBy = "CreatedBy", subject = "Subject", lessonNo = "LessonNo"
        case timeFrom = "TimeFrom", addDate = "AddDate"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        date = try? c.decode(String.self, forKey: .date)
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        category = try? c.decode(Ref.self, forKey: .category)
        createdBy = try? c.decode(Ref.self, forKey: .createdBy)
        subject = try? c.decode(Ref.self, forKey: .subject)
        lessonNo = c.decodeFlexInt(.lessonNo)
        timeFrom = try? c.decode(String.self, forKey: .timeFrom)
        addDate = try? c.decode(String.self, forKey: .addDate)
    }
}

struct RawEventCategoriesResponse: Decodable {
    let categories: [RawEventCategory]
    enum CodingKeys: String, CodingKey { case categories = "Categories" }
}

struct RawEventCategory: Decodable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey { case id = "Id", name = "Name" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
    }
}
