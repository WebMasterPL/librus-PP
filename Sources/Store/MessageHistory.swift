import Foundation

/// Messages sent from this app, kept whole (recipient ids + category, subject,
/// body) so the compose screen can offer them back as one-tap suggestions —
/// the server's "Wysłane" list only carries a display name, not the login id
/// Librus needs to address a message.
enum MessageHistory {
    struct Entry: Codable, Identifiable, Hashable {
        var id: Date { sentAt }
        let sentAt: Date
        let recipients: [MessagesClient.Recipient]
        let category: MessagesClient.RecipientCategory?
        let subject: String
        let body: String
    }

    private static let key = "messageHistory.v1"
    private static let limit = 15

    static func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return list
    }

    static func record(_ entry: Entry) {
        // The same recipients + subject again replaces the older copy.
        var list = load().filter {
            !($0.subject == entry.subject && Set($0.recipients.map(\.id)) == Set(entry.recipients.map(\.id)))
        }
        list.insert(entry, at: 0)
        if let data = try? JSONEncoder().encode(Array(list.prefix(limit))) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
