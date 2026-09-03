import Foundation

/// `Timetables?weekStart=YYYY-MM-DD` ->
/// `{ "Timetable": { "2026-09-01": [ [ {lesson} ], [], [ {lesson} ] ] } }`
/// Outer array = lesson slots for the day; inner array = 0..n lessons in that slot.
struct RawTimetableResponse: Decodable {
    let days: [String: [[RawLesson]]]

    enum CodingKeys: String, CodingKey { case timetable = "Timetable" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Decode day-by-day so one malformed day doesn't lose the whole week.
        guard let dayContainer = try? c.nestedContainer(keyedBy: DynamicKey.self, forKey: .timetable) else {
            days = [:]
            return
        }
        var result: [String: [[RawLesson]]] = [:]
        for key in dayContainer.allKeys {
            if let day = try? dayContainer.decode([[RawLesson]].self, forKey: key) {
                result[key.stringValue] = day
            }
        }
        days = result
    }
}

struct RawLesson: Decodable {
    let lessonNo: Int?
    let hourFrom: String?
    let hourTo: String?
    let subject: NamedRef?
    let teacher: PersonRef?
    let classroom: NamedRef?
    let isSubstitution: Bool
    let isCancelled: Bool
    let orgDate: String?
    let orgSubject: NamedRef?
    let orgTeacher: PersonRef?
    let orgClassroom: NamedRef?

    enum CodingKeys: String, CodingKey {
        case lessonNo = "LessonNo", hourFrom = "HourFrom", hourTo = "HourTo"
        case subject = "Subject", teacher = "Teacher", classroom = "Classroom"
        case isSubstitution = "IsSubstitutionClass", isCancelled = "IsCanceled"
        case orgDate = "OrgDate", orgSubject = "OrgSubject", orgTeacher = "OrgTeacher"
        case orgClassroom = "OrgClassroom"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lessonNo = c.decodeFlexInt(.lessonNo)
        hourFrom = try? c.decode(String.self, forKey: .hourFrom)
        hourTo = try? c.decode(String.self, forKey: .hourTo)
        subject = try? c.decode(NamedRef.self, forKey: .subject)
        teacher = try? c.decode(PersonRef.self, forKey: .teacher)
        classroom = try? c.decode(NamedRef.self, forKey: .classroom)
        isSubstitution = (try? c.decode(Bool.self, forKey: .isSubstitution)) ?? false
        isCancelled = (try? c.decode(Bool.self, forKey: .isCancelled)) ?? false
        orgDate = try? c.decode(String.self, forKey: .orgDate)
        orgSubject = try? c.decode(NamedRef.self, forKey: .orgSubject)
        orgTeacher = try? c.decode(PersonRef.self, forKey: .orgTeacher)
        orgClassroom = try? c.decode(NamedRef.self, forKey: .orgClassroom)
    }
}

/// Timetable entities are inlined with a name, not just an id.
struct NamedRef: Decodable {
    let id: Int
    let name: String?

    enum CodingKeys: String, CodingKey { case id = "Id", name = "Name" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        name = try? c.decode(String.self, forKey: .name)
    }
}

struct PersonRef: Decodable {
    let id: Int
    let firstName: String?
    let lastName: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id", firstName = "FirstName", lastName = "LastName"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeFlexInt(.id) ?? -1
        firstName = try? c.decode(String.self, forKey: .firstName)
        lastName = try? c.decode(String.self, forKey: .lastName)
    }

    var displayName: String? {
        let n = "\((firstName ?? "")) \((lastName ?? ""))".trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? nil : n
    }
}
