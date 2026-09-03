import Foundation

/// Librus references related entities as `{ "Id": 123 }` (sometimes `"Id": "123"`).
struct Ref: Codable, Hashable {
    let id: Int

    enum CodingKeys: String, CodingKey { case id = "Id" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let i = try? c.decode(Int.self, forKey: .id) {
            id = i
        } else if let s = try? c.decode(String.self, forKey: .id), let i = Int(s) {
            id = i
        } else {
            id = -1
        }
    }

    init(id: Int) { self.id = id }
}

extension KeyedDecodingContainer {
    func decodeFlexInt(_ key: Key) -> Int? {
        if let i = try? decode(Int.self, forKey: key) { return i }
        if let s = try? decode(String.self, forKey: key) { return Int(s) }
        return nil
    }
}

/// String-keyed `CodingKey` for decoding objects with arbitrary keys (dates, ids).
struct DynamicKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
