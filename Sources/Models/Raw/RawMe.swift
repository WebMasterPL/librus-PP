import Foundation

struct RawMeResponse: Decodable {
    let me: RawMe
    enum CodingKeys: String, CodingKey { case me = "Me" }
}

struct RawMe: Decodable {
    let account: Account?
    let user: Person?
    let refreshDate: String?

    enum CodingKeys: String, CodingKey {
        case account = "Account", user = "User", refreshDate = "RefreshDate"
    }

    struct Account: Decodable {
        let firstName: String?
        let lastName: String?
        let email: String?
        let groupId: Int?

        enum CodingKeys: String, CodingKey {
            case firstName = "FirstName", lastName = "LastName", email = "Email", groupId = "GroupId"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            firstName = try? c.decode(String.self, forKey: .firstName)
            lastName = try? c.decode(String.self, forKey: .lastName)
            email = try? c.decode(String.self, forKey: .email)
            groupId = c.decodeFlexInt(.groupId)
        }
    }

    struct Person: Decodable {
        let firstName: String?
        let lastName: String?
        enum CodingKeys: String, CodingKey { case firstName = "FirstName", lastName = "LastName" }
    }

    var displayName: String {
        let first = user?.firstName ?? account?.firstName ?? ""
        let last = user?.lastName ?? account?.lastName ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
}
