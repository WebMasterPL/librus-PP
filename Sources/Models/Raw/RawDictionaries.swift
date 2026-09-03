import Foundation

// Reference / lookup collections from the Librus 2.0 API.
// Field names mirror the API (PascalCase) via CodingKeys.

struct RawSubjectsResponse: Decodable {
    let subjects: [RawSubject]
    enum CodingKeys: String, CodingKey { case subjects = "Subjects" }
}

struct RawSubject: Decodable {
    let id: Int
    let name: String
    let short: String

    enum CodingKeys: String, CodingKey { case id = "Id", name = "Name", short = "Short" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        short = (try? c.decode(String.self, forKey: .short)) ?? ""
    }
}

struct RawUsersResponse: Decodable {
    let users: [RawUser]
    enum CodingKeys: String, CodingKey { case users = "Users" }
}

struct RawUser: Decodable {
    let id: Int
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case id = "Id", firstName = "FirstName", lastName = "LastName"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        firstName = (try? c.decode(String.self, forKey: .firstName)) ?? ""
        lastName = (try? c.decode(String.self, forKey: .lastName)) ?? ""
    }

    var displayName: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces) }
}

struct RawClassroomsResponse: Decodable {
    let classrooms: [RawClassroom]
    enum CodingKeys: String, CodingKey { case classrooms = "Classrooms" }
}

struct RawClassroom: Decodable {
    let id: Int
    let name: String
    let symbol: String

    enum CodingKeys: String, CodingKey { case id = "Id", name = "Name", symbol = "Symbol" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
    }

    var displayName: String { name.isEmpty ? symbol : name }
}

struct RawGradeCategoriesResponse: Decodable {
    let categories: [RawGradeCategory]
    enum CodingKeys: String, CodingKey { case categories = "Categories" }
}

struct RawGradeCategory: Decodable {
    let id: Int
    let name: String
    let countToAverage: Bool
    let weight: Double

    enum CodingKeys: String, CodingKey {
        case id = "Id", name = "Name"
        case countToAverage = "CountToTheAverage", weight = "Weight"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        countToAverage = (try? c.decode(Bool.self, forKey: .countToAverage)) ?? false
        weight = (try? c.decode(Double.self, forKey: .weight)) ?? 0
    }

    var effectiveWeight: Double { countToAverage ? weight : 0 }
}

struct RawLessonsResponse: Decodable {
    let lessons: [RawLessonDef]
    enum CodingKeys: String, CodingKey { case lessons = "Lessons" }
}

/// The `Lessons` endpoint maps a lesson id -> subject + teacher (used to enrich attendance).
struct RawLessonDef: Decodable {
    let id: Int
    let teacher: Ref?
    let subject: Ref?

    enum CodingKeys: String, CodingKey { case id = "Id", teacher = "Teacher", subject = "Subject" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        teacher = try? c.decode(Ref.self, forKey: .teacher)
        subject = try? c.decode(Ref.self, forKey: .subject)
    }
}

struct RawAttendanceTypesResponse: Decodable {
    let types: [RawAttendanceType]
    enum CodingKeys: String, CodingKey { case types = "Types" }
}

struct RawAttendanceType: Decodable {
    let id: Int
    let name: String
    let short: String
    let colorRGB: String?
    let standard: Bool
    let standardTypeId: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id", name = "Name", short = "Short"
        case colorRGB = "ColorRGB", standard = "Standard", standardType = "StandardType"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        short = (try? c.decode(String.self, forKey: .short)) ?? ""
        colorRGB = try? c.decode(String.self, forKey: .colorRGB)
        standard = (try? c.decode(Bool.self, forKey: .standard)) ?? false
        standardTypeId = (try? c.decode(Ref.self, forKey: .standardType))?.id
    }

    /// Normalised category used for the attendance summary.
    var kind: AttendanceKind {
        switch standardTypeId ?? id {
        case 1: return .absent
        case 2: return .belated
        case 3: return .absentExcused
        case 4: return .released
        default: return standard ? .present : .presentCustom
        }
    }
}
